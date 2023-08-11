#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

# this script is only tested on Ubuntu 20.04
if [ $(lsb_release -si) != "Ubuntu" ] || [ $(lsb_release -sr) != "20.04" ]; then
  err "This server is not running Ubuntu 20.04"
  err "Terminating script..."
  exit 1
fi

configure_ufw() {
  if [ "$(ufw status | grep -qw inactive >/dev/null 2>/dev/null; echo $?)" = '1' ] || [ "$(ufw show added | grep -qw None >/dev/null 2>/dev/null; echo $?)" = '1' ]; then
    warn "This server have pending firewall rules or ufw is already enabled" && \
      warn "Resetting ufw to default..." && \
      ufw --force disable && \
      ufw --force reset && \
      info "Reset completed"
  fi
  info "Configuring ufw..." && \
    sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw && \
    ufw default deny incoming && \
    ufw default allow outgoing && \
    ufw allow 22/tcp comment 'Default SSH' && \
    ufw allow ${SSH_PORT}/tcp comment 'Custom SSH' && \
    ufw allow from ${KUBE_INT_NET} && \
    info "Enabling ufw..." && \
    ufw --force enable && \
    ufw status numbered

  if [ "$(ufw status | grep -qw active >/dev/null 2>/dev/null; echo $?)" != '0' ]; then
    err "ufw is not active"
    err "Terminating script..."
    exit 1
  else
    info "ufw configured and enabled"
  fi
}

upgrade_packages() {
  info "Updating packages..." && \
    apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y autoremove && \
    apt-get -y autoclean && \
    info "Package update completed"
}

disable_autoupgrade() {
  info "Disabling apt auto updates..." && \
    sed -i 's/Update-Package-Lists "1"/Update-Package-Lists "0"/g' /etc/apt/apt.conf.d/20auto-upgrades && \
    sed -i 's/Unattended-Upgrade "1"/Unattended-Upgrade "0"/g' /etc/apt/apt.conf.d/20auto-upgrades && \
    info "Auto updates disabled"
}

setup_ntp() {
  info "Installing chrony and configuring timezone..." && \
    apt-get -y install chrony && \
    timedatectl set-timezone Asia/Singapore

  if ! service_active chrony; then
    warn "chrony service is not running"
  else
    info "chrony installed and configured"
  fi
}

harden_sshd() {
  info "Configuring SSH daemon..." && \
    cat > /etc/ssh/sshd_config.d/10-cloudlab.conf <<EOF
Port ${SSH_PORT}
LogLevel VERBOSE
LoginGraceTime 1m
PermitRootLogin without-password
MaxAuthTries 4
MaxSessions 10
PubkeyAuthentication yes
HostbasedAuthentication no
IgnoreRhosts yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
UsePAM yes
AllowTcpForwarding yes
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 3
MaxStartups 10:30:60
Banner /etc/issue.net
HostKeyAlgorithms rsa-sha2-512,rsa-sha2-256,ssh-ed25519
Ciphers chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256
EOF

  info "Removing insecure host keys..." && \
    rm -f /etc/ssh/ssh_host_dsa* && \
    rm -f /etc/ssh/ssh_host_ecdsa* && \
    info "Removing Diffie-Hellman keys lesser than 3072 bits..." && \
    awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.tmp && \
    mv /etc/ssh/moduli.tmp /etc/ssh/moduli && \
    info "Restarting SSH daemon..." && \
    systemctl restart sshd && \
    systemctl status sshd --no-pager

  if ! service_active sshd; then
    err "SSH daemon is not running"
    err "Terminating script..."
    exit 1
  else
    info "SSH daemon configured and restarted"
  fi
}

configure_remote_syslog() {
  info "Configuring rsyslog..." && \
    cat > /etc/rsyslog.d/22-logdna.conf <<EOF
global(
    DefaultNetstreamDriverCAFile="/etc/ld-root-ca.crt"
)

template(name="LogDNAFormat" type="list") {
    constant(value="<")
    property(name="pri")
    constant(value=">")
    property(name="protocol-version")
    constant(value=" ")
    property(name="timestamp" dateFormat="rfc3339")
    constant(value=" ")
    property(name="hostname")
    constant(value=" ")
    property(name="app-name")
    constant(value=" ")
    property(name="procid")
    constant(value=" ")
    property(name="msgid")
    constant(value=" [logdna@48950 key=\"${LOGDNA_KEY}\"] ")
    property(name="msg")
}

*.* action(
    type="omfwd"
    template="LogDNAFormat"
    target="syslog-a.logdna.com"
    protocol="tcp"
    port="6514"
    StreamDriver="gtls"                         # use gtls netstream driver
    StreamDriverMode="1"                        # require TLS
    StreamDriverAuthMode="x509/name"            # authenticate by hostname
    StreamDriverPermittedPeers="*.logdna.com"
    queue.filename="logdnaFwd"
    queue.maxDiskSpace="1g"
    queue.saveOnShutdown="on"
    queue.type="LinkedList"
    Action.ResumeRetryCount="-1"
    KeepAlive="on"
)
EOF

  info "Setting up syslog over TLS..." && \
    apt-get -y install rsyslog-gnutls && \
    wget https://assets.logdna.com/rootca/ld-root-ca.crt -O /etc/ld-root-ca.crt && \
    info "Restarting rsyslog..." && \
    systemctl restart rsyslog && \
    systemctl status rsyslog --no-pager

  if ! service_active rsyslog; then
    warn "Rsyslog service is not running"
  else
    info "Rsyslog configured and restarted"
  fi
}

setup_kernel() {
  info "Setting up kernel modules and parameters..." && \
    modprobe overlay && \
    modprobe br_netfilter && \
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

  cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system
}

install_containerd() {
  info "Installing containerd..." && \
    apt-get update && \
    apt-get install -y containerd && \
    mkdir -p /etc/containerd && \
    containerd config default | sudo tee /etc/containerd/config.toml && \
    systemctl restart containerd && \
    systemctl status containerd --no-pager

  if ! service_active containerd; then
    warn "Containerd service is not running"
  else
    info "Containerd configured and started"
  fi
}

disable_swap() {
  info "Disabling swap..." && \
    swapoff -a && \
    sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab
}

install_kubernetes() {
  info "Installing kubernetes prerequisites..." && \
    apt-get update && \
    apt-get install -y apt-transport-https curl && \
    info "Importing kubernetes repository GPG key..." && \
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
    info "Adding kubernetes repository" && \
    cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

  info "Installing kubernetes..." && \
    apt-get update && \
    apt-get install -y kubelet=${KUBE_VERSION}-${KUBE_RELEASE} kubeadm=${KUBE_VERSION}-${KUBE_RELEASE} kubectl=${KUBE_VERSION}-${KUBE_RELEASE} && \
    apt-mark hold kubelet kubeadm kubectl
}

configure_kubelet() {
  info "Configuring kubelet service..."

  if grep -- "--node-ip=" ${KUBE_ADM_CONFIG_FILE} &> /dev/null; then
    err "Node IP is already set in kubelet configuration file"
    exit 1
  elif grep "KUBELET_EXTRA_ARGS=" ${KUBE_ADM_CONFIG_FILE} &> /dev/null; then
    sed -i "s@KUBELET_EXTRA_ARGS=@KUBELET_EXTRA_ARGS=--node-ip=${KUBE_MASTER} @g" ${KUBE_ADM_CONFIG_FILE}
  else
    sed -i "/^\[Service\]/a\Environment=\"KUBELET_EXTRA_ARGS=--node-ip=${KUBE_MASTER}\"" ${KUBE_ADM_CONFIG_FILE}
  fi

  systemctl daemon-reload && \
    systemctl restart kubelet

  systemctl status kubelet --no-pager
  if ! service_active kubelet; then
    warn "Kubelet service is not running"
  else
    info "Kubelet configured and restarted"
  fi
}

configure_ufw
upgrade_packages
disable_autoupgrade
setup_ntp
harden_sshd
configure_remote_syslog
setup_kernel
install_containerd
disable_swap
install_kubernetes
configure_kubelet

} # this ensures the entire script is downloaded #