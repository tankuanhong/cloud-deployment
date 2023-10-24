#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || fatal_err "${SCRIPT_PATH}/conf/teleport.conf is missing"

# harden os
source ${SCRIPT_PATH}/scripts/common-harden-ubuntu.sh || fatal_err "Failed to harden os"

# allow http and https
web_firewall_rules() {
  info "Allow web services on ufw..." && \
    ufw allow http && \
    ufw allow https && \
    info "Failed to add web services on ufw"
}

# install teleport
install_teleport() {
  info "Installing Teleport..." && \
    sudo curl https://apt.releases.teleport.dev/gpg -o /usr/share/keyrings/teleport-archive-keyring.asc && \
    source /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] \
      https://apt.releases.teleport.dev/${ID?} ${VERSION_CODENAME?} stable/v${TELEPORT_VERSION}" \
      | sudo tee /etc/apt/sources.list.d/teleport.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install teleport

  if ! command_exist "teleport"; then
    fatal_err "Teleport not found after installation"
  else
    info "Teleport installed"
  fi
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
    info "Downloading caddy binary..." && \
    wget -O /usr/bin/caddy ${CADDY_DOWNLOAD_URL} && \
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
    fatal_err "Caddy not found after installation"
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
            "layer4",
            "tls"
        ]
      }
    }
  },
  "apps": {
    "http": {
      "servers": {
        "srv0": {
          "listen": [
            ":80"
          ],
          "routes": [
            {
              "handle": [
                {
                  "handler": "static_response",
                  "headers": {
                    "Location": [
                      "https://{http.request.host}{http.request.uri}"
                    ]
                  },
                  "status_code": 302
                }
              ]
            }
          ]
        }
      }
    },
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
                      "${TELEPORT_PUBLIC_ADDR}"
                    ]
                  }
                }
              ],
              "handle": [
                {
                  "handler": "proxy",
                  "proxy_protocol": "v2",
                  "upstreams": [
                    {
                      "dial": [
                        "${CADDY_BACKEND}:3080"
                      ]
                    }
                  ]
                }
              ]
            }
          ]
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
                "ca": "https://${LE_ENDPOINT}/directory",
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

  info "Add Caddy backend to hosts file..." && \
    echo "127.0.0.1 ${CADDY_BACKEND}" | sudo tee -a /etc/hosts

  info "Set Caddy service to use JSON config..." && \
    sed -i 's/\/etc\/caddy\/Caddyfile/\/etc\/caddy\/caddy.json/g' /lib/systemd/system/caddy.service && \
    systemctl daemon-reload && \
    systemctl enable caddy
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
  listen_addr: 0.0.0.0:${TELEPORT_AUTH_PORT}
  session_recording: "node-sync"
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
  labels:
    env: tbc
  commands:
  - name: hostname
    command: [hostname]
    period: 1m0s
  disable_create_host_user: true
  pam:
    enabled: true
    service_name: "sshd"

# This section configures the 'proxy service'
proxy_service:
  enabled: "yes"
  proxy_protocol: "on"
  web_listen_addr: 0.0.0.0:${TELEPORT_PROXY_PORT}
  public_addr: ${TELEPORT_PUBLIC_ADDR}:443
  https_keypairs:
  - key_file: /var/lib/caddy/.local/share/caddy/certificates/${LE_ENDPOINT}-directory/wildcard_.${CADDY_ROOT_DOMAIN}/wildcard_.${CADDY_ROOT_DOMAIN}.key
    cert_file: /var/lib/caddy/.local/share/caddy/certificates/${LE_ENDPOINT}-directory/wildcard_.${CADDY_ROOT_DOMAIN}/wildcard_.${CADDY_ROOT_DOMAIN}.crt
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

  info "Sleep 1 minute for Caddy certificate request..." && \
    sleep 60 && \
    info "Wake after 1 minute"

  info "Starting Teleport..." && \
    systemctl enable teleport && \
    systemctl start teleport && \
    systemctl status teleport --no-pager

  if ! service_active teleport; then
    fatal_err "Teleport service is not running"
  else
    info "Teleport configured and started"
  fi
}

install_fail2ban() {
  info "Installing fail2ban..." && \
    apt-get -y install fail2ban

  if ! service_active fail2ban; then
    fatal_err "fail2ban service is not running"
  else
    info "fail2ban installed"
  fi
}

configure_fail2ban() {
  info "Configuring fail2ban..." && \
    info "Creating caddy filter..." && \
    cat > /etc/fail2ban/filter.d/caddy.conf <<EOF
[Definition]
failregex = ^{"level":"debug","ts":"","logger":"layer4","msg":"matching","remote":"<HOST>:[0-9]{0,5}","matcher":"layer4\.matchers\.tls","matched":false}$
ignoreregex =
EOF

  info "Creating custom jail..." && \
    cat > /etc/fail2ban/jail.d/main.conf <<EOF
[DEFAULT]
bantime.increment = true
bantime.factor = 1
bantime.maxtime = 3w

[sshd]
port = ${SSH_PORT}
mode = aggressive

[caddy]
enabled = true
filter = caddy
logpath = /var/log/caddy/caddy.log
maxretry = 10
findtime = 3600
bantime = 900
action = iptables-allports
EOF

  info "Restarting fail2ban with new configuration" && \
    systemctl enable fail2ban && \
    systemctl restart fail2ban && \
    systemctl status fail2ban --no-pager && \
    if ! service_active fail2ban; then
      fatal_err "fail2ban service is not running"
    else
      info "fail2ban configured and started"
    fi
}

install_kopia() {
  info "Installing kopia..." && \
    curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list && \
    apt update && \
    apt install kopia && \
    if ! command_exist "kopia"; then
      fatal_err "kopia not found after installation"
    else
      info "kopia installed"
    fi
}

configure_kopia() {
  info "Configuring kopia..." && \
    cat > /etc/systemd/system/kopia.service <<EOF
[Unit]
Description=Kopia HTTP Server
Documentation=https://kopia.io/docs/reference/
After=basic.target network.target

[Service]
ExecStart=/usr/bin/kopia server start --address="${KOPIA_WEB_UI}" --insecure --without-password --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"
ExecStop=/usr/bin/kopia server shutdown
ExecReload=/usr/bin/kopia server refresh --address="${KOPIA_WEB_UI}"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  info "Connecting to backup repository..."
  if [ "$(/usr/bin/kopia repository connect s3 --endpoint="${KOPIA_S3_URL}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
    warn "Error connecting or repository not initialized"
    if ${KOPIA_REPO_INIT}; then
      info "Attempting to initialize repository"
      if [ "$(/usr/bin/kopia repository create s3 --endpoint="${KOPIA_S3_URL}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
        warn "Unable to connect to repository"
      else
        info "Repository initialized"
      fi
    else
      warn "Check repository credentials then manually connect through kopia Web UI"
    fi
  else
    info "Repository connected"
  fi

  info "Starting kopia service..." && \
    systemctl daemon-reload && \
    systemctl enable kopia && \
    systemctl start kopia && \
    systemctl status kopia --no-pager

  if ! service_active kopia; then
    warn "kopia service is not running"
  else
    info "kopia configured and started"
  fi
}

install_cron() {
  info "Install cron jobs..."
  if [ "$(crontab ${SCRIPT_PATH}/assets/teleport/teleport.cron; echo $?)" = '0' ]; then
    info "Cron installed successfully"
  else
    warn "Failed to install cron jobs"
  fi
}

web_firewall_rules
install_teleport
install_caddy
configure_caddy
configure_teleport
install_fail2ban
configure_fail2ban
install_kopia
configure_kopia
install_cron

} # this ensures the entire script is downloaded #