#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${BASH_SOURCE%/*}/shell-logger/shell-logger" || exit
source "${BASH_SOURCE%/*}/deploy.conf" || exit


# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

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
    ufw status numbered && \
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
    timedatectl set-timezone Asia/Singapore && \
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
AllowTcpForwarding no
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
    systemctl status sshd --no-pager && \
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
    constant(value=" [logdna@48950 key=\"$LOGDNA_KEY\"] ")
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
    systemctl status rsyslog --no-pager && \
    if ! service_active rsyslog; then
      warn "Rsyslog service is not running"
    else
      info "Rsyslog configured and restarted"
    fi
}

install_teleport() {
  info "Installing Teleport..." && \
    sudo curl https://apt.releases.teleport.dev/gpg -o /usr/share/keyrings/teleport-archive-keyring.asc && \
    source /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] \
      https://apt.releases.teleport.dev/${ID?} ${VERSION_CODENAME?} stable/v12" \
      | sudo tee /etc/apt/sources.list.d/teleport.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install teleport && \
    if ! command_exist "teleport"; then
      err "Teleport not found after installation"
      err "Terminating script..."
    else
      info "Teleport installed"
    fi
}

install_caddy() {
  info "Installing Caddy..." && \
    cp caddy/caddy_*_linux_amd64_cloudflare /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    /usr/bin/caddy completion bash | sudo tee /etc/bash_completion.d/caddy && \
    cp caddy/caddy.service /lib/systemd/system/caddy.service && \
    cp caddy/caddy-api.service /lib/systemd/system/caddy-api.service && \
    systemctl daemon-reload && \
    /usr/bin/caddy manpage --directory man && \
    gzip -r man/ && \
    cp man/* /usr/share/man/man8/ && \
    mandb && \
    if ! command_exist "caddy"; then
      err "Caddy not found after installation"
      err "Terminating script..."
    else
      info "Caddy installed"
    fi
}

configure_caddy() {
  info "Configuring Caddy..." && \
    cat > /etc/caddy/caddy.json <<EOL
{
  "apps": {
    "http": {
      "servers": {
        "srv0": {
          "listen": [
            ":443"
          ],
          "routes": [
            {
              "match": [
                {
                  "host": [
                    "${TELEPORT_PUBLIC_ADDR}"
                  ]
                }
              ],
              "handle": [
                {
                  "handler": "subroute",
                  "routes": [
                    {
                      "handle": [
                        {
                          "handler": "reverse_proxy",
                          "transport": {
                            "protocol": "http",
                            "tls": {}
                          },
                          "upstreams": [
                            {
                              "dial": "localhost:3080"
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ],
              "terminal": true
            }
          ],
          "tls_connection_policies": [
            {
              "match": {
                "sni": [
                  "*.${CADDY_ROOT_DOMAIN}"
                ]
              }
            }
          ],
          "automatic_https": {
            "disable": true
          }
        }
      }
    },
    "tls": {
      "certificates": {
        "automate": [
          "*.${CADDY_ROOT_DOMAIN}"
        ]
      },
      "automation": {
        "policies": [
          {
            "subjects": [
              "*.${CADDY_ROOT_DOMAIN}"
            ],
            "issuers": [
              {
                "ca": "${CADDY_CA_URL}",
                "challenges": {
                  "dns": {
                    "provider": {
                      "api_token": "${CLOUDFLARE_API_TOKEN}",
                      "name": "cloudflare"
                    }
                  }
                },
                "email": "${CADDY_ACME_EMAIL}",
                "module": "acme"
              }
            ]
          }
        ]
      }
    }
  }
}
EOL

  info "Set Caddy service to use JSON config..." && \
    sed -i 's/\/etc\/caddy\/Caddyfile/\/etc\/caddy\/caddy.json/g' /lib/systemd/system/caddy.service && \
    systemctl daemon-reload && \
    systemctl restart caddy
}

configure_teleport() {
  info "Configuring Teleport..." && \
    cat > /etc/teleport.yaml <<EOF
# By default, this file should be stored in /etc/teleport.yaml

# Configuration file version. The current version is "v3".
version: v3

# This section of the configuration file applies to all teleport services
teleport:
  data_dir: /var/lib/teleport
  diag_addr: "127.0.0.1:3000"
  connection_limits:
    max_connections: 1000
    max_users: 250
  log:
    output: stderr
    severity: INFO
    format:
      output: text
  storage:
    type: sqlite
  ciphers:
    - aes128-ctr
    - aes192-ctr
    - aes256-ctr
    - aes128-gcm@openssh.com
    - chacha20-poly1305@openssh.com
  kex_algos:
    - curve25519-sha256
    - curve25519-sha256@libssh.org
    - diffie-hellman-group14-sha256
  mac_algos:
    - hmac-sha2-256-etm@openssh.com
  ciphersuites:
    - tls-ecdhe-rsa-with-aes-128-gcm-sha256
    - tls-ecdhe-ecdsa-with-aes-128-gcm-sha256
    - tls-ecdhe-rsa-with-aes-256-gcm-sha384
    - tls-ecdhe-ecdsa-with-aes-256-gcm-sha384
    - tls-ecdhe-rsa-with-chacha20-poly1305
    - tls-ecdhe-ecdsa-with-chacha20-poly1305

# This section configures the 'auth service'
auth_service:
  enabled: "yes"
  cluster_name: ${TELEPORT_CLUSTER}
  proxy_protocol: "on"
  authentication:
    type: local
    second_factor: otp
    require_session_mfa: "yes"
  listen_addr: 0.0.0.0:${TELEPORT_AUTH_PORT}
  session_recording: "node"
  proxy_checks_host_keys: "yes"
  client_idle_timeout: never
  client_idle_timeout_message: ""
  web_idle_timeout: 10m
  disconnect_expired_cert: "no"
  keep_alive_interval: 5m
  keep_alive_count_max: 3
  message_of_the_day: ""
  proxy_listener_mode: multiplex

# This section configures the 'node service'
ssh_service:
  enabled: "yes"
  listen_addr: 0.0.0.0:3022
  commands:
  - name: hostname
    command: [hostname]
    period: 1m0s

# This section configures the 'proxy service'
proxy_service:
  enabled: "yes"
  web_listen_addr: 0.0.0.0:${TELEPORT_PROXY_PORT}
  public_addr: ${TELEPORT_PUBLIC_ADDR}:443
  https_keypairs:
  - key_file: /etc/ssl/private/teleport.key
    cert_file: /etc/ssl/certs/teleport.crt
  https_keypairs_reload_interval: 1h
  acme: {}

# This section configures the 'application service'
app_service:
  enabled: "no"

# This section configures the 'kubernetes service'
kubernetes_service:
  enabled: "no"

# This section configures the 'discovery service'
discovery_service:
  enabled: "no"

# This section configures the 'database service'
db_service:
  enabled: "no"

# This section configures the windows desktop service
windows_desktop_service:
  enabled: "no"
EOF

  info "Starting Teleport..." && \
    systemctl enable teleport && \
    systemctl start teleport && \
    systemctl status teleport --no-pager && \
    if ! service_active teleport; then
      warn "Teleport service is not running"
    else
      info "Teleport configured and started"
    fi
}

main() {
  configure_ufw
  upgrade_packages
  disable_autoupgrade
  setup_ntp
  harden_sshd
  configure_remote_syslog
  install_teleport
  install_caddy
  configure_caddy
  configure_teleport
}

main

} # this ensures the entire script is downloaded #