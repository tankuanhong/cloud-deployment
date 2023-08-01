#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/syncthing.conf" || exit

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
    ufw allow http && \
    ufw allow https && \
    ufw allow ${SSH_PORT}/tcp comment 'Custom SSH' && \
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

install_discovery() {
  info "Installing Syncthing Discovery Server..." && \
    info "Creating stdiscosrv user..."
    groupadd --system stdiscosrv && \
    useradd --system \
      --gid stdiscosrv \
      --create-home \
      --home-dir /var/lib/stdiscosrv \
      --shell /usr/sbin/nologin \
      --comment "Syncthing Discovery Server" \
      stdiscosrv && \
    info "Installing Syncthing Discovery Server binary..." && \
    wget ${ST_DISCOSRV_BINARY_URL} && \
    tar xzvf stdiscosrv-*.tar.gz && \
    mv stdiscosrv-*/stdiscosrv /usr/bin/stdiscosrv && \
    info "Installing service file..." && \
    cp "${SCRIPT_PATH}/assets/syncthing/stdiscosrv.service" /lib/systemd/system/stdiscosrv.service && \
    systemctl daemon-reload && \
    info "Starting Syncthing Discovery Server..." && \
    systemctl enable stdiscosrv
    systemctl restart stdiscosrv
}

install_relay() {
  info "Installing Syncthing Relay Server..." && \
    info "Creating strelaysrv user..."
    groupadd --system strelaysrv && \
    useradd --system \
      --gid strelaysrv \
      --create-home \
      --home-dir /var/lib/strelaysrv \
      --shell /usr/sbin/nologin \
      --comment "Syncthing Relay Server" \
      strelaysrv && \
    info "Installing Syncthing Relay Server binary..." && \
    wget ${ST_RELAYSRV_BINARY_URL} && \
    tar xzvf strelaysrv-*.tar.gz && \
    mv strelaysrv-*/strelaysrv /usr/bin/strelaysrv && \
    info "Installing service file..." && \
    cp "${SCRIPT_PATH}/assets/syncthing/strelaysrv.service" /lib/systemd/system/strelaysrv.service && \
    systemctl daemon-reload && \
    info "Starting Syncthing Relay Server..." && \
    systemctl enable strelaysrv
    systemctl restart strelaysrv
}

install_caddy() {
  info "Installing Caddy..." && \
    info "Creating caddy user..." && \
    groupadd --system caddy && \
    useradd --system \
      --gid caddy \
      --create-home \
      --home-dir /var/lib/caddy \
      --shell /usr/sbin/nologin \
      --comment "Caddy web server" \
      caddy && \
    if getent group www-data >/dev/null; then
      usermod -aG www-data caddy
    fi && \
    info "Creating caddy directories..." && \
    mkdir -p /etc/caddy && \
    mkdir -p /var/log/caddy && \
    mkdir -p /var/lib/caddy && \
    info "Copying caddy binary..." && \
    cp "${SCRIPT_PATH}/assets/caddy/linux/2.6.4/caddy-cloudflare-layer4-l4tls-l4proxy" /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    info "Setting permissions..." && \
    chown caddy:caddy /usr/bin/caddy && \
    chown -R caddy:caddy /etc/caddy && \
    chown -R caddy:caddy /var/log/caddy && \
    chown -R caddy:caddy /var/lib/caddy && \
    info "Creating caddy service files..." && \
    cp "${SCRIPT_PATH}/assets/caddy/caddy.service" /lib/systemd/system/caddy.service && \
    cp "${SCRIPT_PATH}/assets/caddy/caddy-api.service" /lib/systemd/system/caddy-api.service && \
    systemctl daemon-reload && \
    info "Setting up caddy bash completion..." && \
    /usr/bin/caddy completion bash | sudo tee /etc/bash_completion.d/caddy && \
    info "Setting up caddy man pages..." && \
    /usr/bin/caddy manpage --directory man && \
    gzip -r man/ && \
    cp man/* /usr/share/man/man8/ && \
    mandb

  if ! command_exist "caddy"; then
    err "Caddy not found after installation"
    err "Terminating script..."
    exit 1
  else
    info "Caddy installed"
  fi
}

configure_caddy() {
  info "Configuring Caddy..." && \
    cat > /etc/caddy/caddy.json <<EOL
{
  "logging": {
    "logs": {
      "default": {
        "writer": {
          "filename": "/var/log/caddy/caddy.log",
          "output": "file",
          "roll_keep": 5,
          "roll_size_mb": 100
        },
        "encoder": {
          "format": "json",
          "time_format": "iso8601"
        },
        "level": "DEBUG",
        "include": [
            "http",
            "layer4"
        ]
      }
    }
  },
  "apps": {
    "layer4": {
      "servers": {
        "srv0": {
          "listen": [
            ":443"
          ],
          "routes": [
            {
              "match": [
                {
                  "tls": {
                    "sni": [
                      "${ST_DISCOSRV_PUBLIC_ADDR}"
                    ]
                  }
                }
              ],
              "handle": [
                {
                  "handler": "proxy",
                  "upstreams": [
                    {
                      "dial": [
                        "localhost:8443"
                      ]
                    }
                  ]
                }
              ]
            },
            {
              "match": [
                {
                  "tls": {
                    "sni": [
                      "${ST_RELAYSRV_PUBLIC_ADDR}"
                    ]
                  }
                }
              ],
              "handle": [
                {
                  "handler": "proxy",
                  "upstreams": [
                    {
                      "dial": [
                        "localhost:22067"
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
  }
}
EOL

  info "Set Caddy service to use JSON config..." && \
    sed -i 's/\/etc\/caddy\/Caddyfile/\/etc\/caddy\/caddy.json/g' /lib/systemd/system/caddy.service && \
    systemctl daemon-reload && \
    systemctl enable caddy
    systemctl restart caddy
}

#install_fail2ban() {
#
#}

#configure_fail2ban() {
#
#}

#install_kopia() {
#
#}

#configure_kopia() {
#
#}

configure_ufw
upgrade_packages
disable_autoupgrade
setup_ntp
harden_sshd
configure_remote_syslog
install_discovery
install_relay
install_caddy
configure_caddy
#install_fail2ban
#configure_fail2ban
#install_kopia
#configure_kopia

} # this ensures the entire script is downloaded #