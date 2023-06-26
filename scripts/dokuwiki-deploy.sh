#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/dokuwiki.conf" || exit

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

install_dokuwiki() {
  info "Installing Dokuwiki..." && \
    info "Installing PHP..." && \
    apt-get -y install php-fpm php-xml php-gd php-curl php-mbstring php-json && \
    info "Installing Dokuwiki files..." && \
    mkdir -p /var/www && \
    wget https://download.dokuwiki.org/src/dokuwiki/dokuwiki-stable.tgz && \
    tar xzvf dokuwiki-stable.tgz -C /var/www && \
    mv /var/www/dokuwiki-* /var/www/dokuwiki && \
    chown -R www-data:www-data /var/www/dokuwiki && \
    find /var/www/dokuwiki -type f -exec chmod 644 {} \; && \
    find /var/www/dokuwiki/* -type d -exec chmod 755 {} \;
}

harden_dokuwiki() {
  info "Hardening Dokuwiki installation..." && \
    cat >> /var/www/dokuwiki/inc/preload.php <<EOF
<?php
// DO NOT use a closing php tag. This causes a problem with the feeds,
// among other things. For more information on this issue, please see:w
// http://www.dokuwiki.org/devel:coding_style#php_closing_tags

define('DOKU_CONF','/var/www/conf/');
EOF

  chown www-data:www-data /var/www/dokuwiki/inc/preload.php && \
    mv /var/www/dokuwiki/data /var/www && \
    mv /var/www/dokuwiki/conf /var/www && \
    echo "\$conf['savedir'] = '/var/www/data';" >> /var/www/conf/local.php
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
            "http.log.access",
            "layer4",
            "layer4.handlers.proxy",
            "layer4.handlers.tls",
            "layer4.matchers.tls",
            "tls",
            "tls.certificates.automate",
            "tls.issuance.acme"
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
                      "${DOKUWIKI_DOMAIN}"
                    ]
                  }
                }
              ],
              "handle": [
                {
                  "handler": "tls",
                  "connection_policies": [
                    {
                      "alpn": [
                        "http/1.1"
                      ]
                    }
                  ]
                },
                {
                  "handler": "proxy",
                  "upstreams": [
                    {
                      "dial": [
                        "localhost:8080"
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
    "http": {
      "servers": {
        "srv0": {
          "listen": [
            ":8080"
          ],
          "routes": [
            {
              "handle": [
                {
                  "handler": "subroute",
                  "routes": [
                    {
                      "handle": [
                        {
                          "handler": "vars",
                          "root": "/var/www/dokuwiki"
                        },
                        {
                          "handler": "headers",
                          "response": {
                            "deferred": true,
                            "delete": [
                              "Server"
                            ],
                            "set": {
                              "Referrer-Policy": [
                                "no-referrer-when-downgrade"
                              ],
                              "Strict-Transport-Security": [
                                "max-age=31536000;"
                              ],
                              "X-Content-Type-Options": [
                                "nosniff"
                              ],
                              "X-Xss-Protection": [
                                "1; mode=block"
                              ]
                            }
                          }
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "rewrite",
                          "uri": "{http.matchers.file.relative}"
                        }
                      ],
                      "match": [
                        {
                          "file": {
                            "try_files": [
                              "{http.request.uri.path}",
                              "{http.request.uri.path}/index.html"
                            ]
                          }
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "encodings": {
                            "gzip": {},
                            "zstd": {}
                          },
                          "handler": "encode"
                        },
                        {
                          "handler": "subroute",
                          "routes": [
                            {
                              "handle": [
                                {
                                  "handler": "subroute",
                                  "routes": [
                                    {
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "strip_path_prefix": "/_media"
                                        }
                                      ]
                                    },
                                    {
                                      "group": "group0",
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "uri": "/lib/exe/fetch.php?media={http.request.uri.path}&{http.request.uri.query}"
                                        }
                                      ]
                                    }
                                  ]
                                }
                              ],
                              "match": [
                                {
                                  "path": [
                                    "/_media/*"
                                  ]
                                }
                              ]
                            },
                            {
                              "handle": [
                                {
                                  "handler": "subroute",
                                  "routes": [
                                    {
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "strip_path_prefix": "/_detail"
                                        }
                                      ]
                                    },
                                    {
                                      "group": "group1",
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "uri": "/lib/exe/detail.php?media={http.request.uri.path}&{http.request.uri.query}"
                                        }
                                      ]
                                    }
                                  ]
                                }
                              ],
                              "match": [
                                {
                                  "path": [
                                    "/_detail/*"
                                  ]
                                }
                              ]
                            },
                            {
                              "handle": [
                                {
                                  "handler": "subroute",
                                  "routes": [
                                    {
                                      "group": "group2",
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "uri": "/doku.php?do=export_{http.regexp.export.1}&{http.request.uri.query}&id={http.regexp.export.2}"
                                        }
                                      ],
                                      "match": [
                                        {
                                          "path_regexp": {
                                            "name": "export",
                                            "pattern": "^/_export/([^/]+)/(.*)"
                                          }
                                        }
                                      ]
                                    }
                                  ]
                                }
                              ],
                              "match": [
                                {
                                  "path": [
                                    "/_export/*"
                                  ]
                                }
                              ]
                            },
                            {
                              "handle": [
                                {
                                  "handler": "subroute",
                                  "routes": [
                                    {
                                      "group": "group3",
                                      "handle": [
                                        {
                                          "handler": "rewrite",
                                          "uri": "/doku.php?{http.request.uri.query}"
                                        }
                                      ]
                                    }
                                  ]
                                }
                              ],
                              "match": [
                                {
                                  "path": [
                                    "/"
                                  ]
                                }
                              ]
                            },
                            {
                              "group": "group4",
                              "handle": [
                                {
                                  "handler": "rewrite",
                                  "uri": "{http.matchers.file.relative}"
                                }
                              ],
                              "match": [
                                {
                                  "file": {
                                    "try_files": [
                                      "{http.request.uri.path}"
                                    ]
                                  }
                                }
                              ]
                            },
                            {
                              "group": "group4",
                              "handle": [
                                {
                                  "handler": "rewrite",
                                  "uri": "{http.matchers.file.relative}?id={http.request.uri.path}&{http.request.uri.query}"
                                }
                              ],
                              "match": [
                                {
                                  "file": {
                                    "try_files": [
                                      "/doku.php"
                                    ]
                                  }
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "static_response",
                          "status_code": 403
                        }
                      ],
                      "match": [
                        {
                          "path": [
                            "/data/*",
                            "/conf/*",
                            "/bin/*",
                            "/inc/*",
                            "/vendor/*",
                            "/install.php",
                            "/.*",
                            "/COPYING",
                            "/README",
                            "/SECURITY.md",
                            "/VERSION",
                            "/composer.*"
                          ]
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "static_response",
                          "headers": {
                            "Location": [
                              "{http.request.uri.path}/"
                            ]
                          },
                          "status_code": 308
                        }
                      ],
                      "match": [
                        {
                          "file": {
                            "try_files": [
                              "{http.request.uri.path}/index.php"
                            ]
                          },
                          "not": [
                            {
                              "path": [
                                "*/"
                              ]
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "rewrite",
                          "uri": "{http.matchers.file.relative}"
                        }
                      ],
                      "match": [
                        {
                          "file": {
                            "split_path": [
                              ".php"
                            ],
                            "try_files": [
                              "{http.request.uri.path}",
                              "{http.request.uri.path}/index.php",
                              "index.php"
                            ]
                          }
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "reverse_proxy",
                          "transport": {
                            "protocol": "fastcgi",
                            "split_path": [
                              ".php"
                            ]
                          },
                          "upstreams": [
                            {
                              "dial": "unix//run/php/php7.4-fpm.sock"
                            }
                          ]
                        }
                      ],
                      "match": [
                        {
                          "path": [
                            "*.php"
                          ]
                        }
                      ]
                    },
                    {
                      "handle": [
                        {
                          "handler": "file_server",
                          "hide": [
                            "./Caddyfile"
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
          "automatic_https": {
            "skip": [
              "localhost"
            ]
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

  info "Set Caddy service to use JSON config..." && \
    sed -i 's/\/etc\/caddy\/Caddyfile/\/etc\/caddy\/caddy.json/g' /lib/systemd/system/caddy.service && \
    systemctl daemon-reload && \
    systemctl enable caddy
    systemctl restart caddy
}

install_fail2ban() {
  info "Installing fail2ban..." && \
    apt-get -y install fail2ban

  if ! service_active fail2ban; then
    warn "fail2ban service is not running"
  else
    info "fail2ban installed"
  fi
}

configure_fail2ban() {
  info "Configuring fail2ban..." && \
    info "Set default jail config..." && \
    cat > /etc/fail2ban/jail.d/main.conf <<EOF
[sshd]
port = ${SSH_PORT}
EOF

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
    systemctl status fail2ban --no-pager

  if ! service_active fail2ban; then
    warn "fail2ban service is not running"
  else
    info "fail2ban configured and started"
  fi
}

install_kopia() {
  info "Installing kopia..." && \
    curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list && \
    apt update && \
    apt install kopia

  if ! command_exist "kopia"; then
    err "kopia not found after installation"
    err "Terminating script..."
    exit 1
  else
    info "kopia installed"
  fi
}

configuring_kopia() {
  info "Configuring kopia..." && \
    cat > /etc/systemd/system/kopia.service <<EOF
[Unit]
Description=Kopia HTTP Server
Documentation=https://kopia.io/docs/reference/
After=basic.target network.target

[Service]
ExecStart=/usr/bin/kopia server start --address="${KOPIA_WEB_UI}" --insecure --without-password --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"
ExecStop=/usr/bin/kopia server shutdown
ExecReload=/usr/bin/kopia server refresh --address="http://127.0.0.1:51515"
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

configure_ufw
upgrade_packages
disable_autoupgrade
setup_ntp
harden_sshd
configure_remote_syslog
install_dokuwiki
harden_dokuwiki
install_caddy
configure_caddy

} # this ensures the entire script is downloaded #