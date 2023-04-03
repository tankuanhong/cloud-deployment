#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${BASH_SOURCE%/*}/shell-logger/shell-logger" || exit
source "${BASH_SOURCE%/*}/common.conf" || exit
source "${BASH_SOURCE%/*}/gitea.conf" || exit


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

install_mariadb() {
  info "Installing MariaDB server..." && \
    apt-get -y install mariadb-server && \
    info "Securing MariaDB installation..." && \
    mysql -u root << EOF
UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE user='root' AND host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE user='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

  if ! service_active mariadb; then
    warn "MariaDB service is not running"
  else
    info "MariaDB installed and running"
  fi
}

configure_mariadb() {
  info "Preparing database..." && \
    mysql -u root << EOF
SET old_passwords=0;
CREATE USER 'gitea' IDENTIFIED BY 'gitea';
CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea';
FLUSH PRIVILEGES;
EOF

  if [ "$(mysql -u gitea -p$DB_PASS -e "SHOW DATABASES LIKE 'giteadb';" >/dev/null 2>/dev/null; echo $?)" = '0' ]; then
    info "Database configured successfully"
  else
    warn "Failed to setup database"
  fi
}

create_service_account() {
  info "Creating Gitea service account..." && \
    adduser --system --shell /bin/bash --gecos 'Gitea' --group --disabled-password --home /home/gitea gitea
}

configure_ext_volume() {
  info "Configuring external volume..." && \
    mkdir /mnt/HC_VOL/repo && \
    chown gitea:gitea /mnt/HC_VOL/repo && \
    chmod 755 /mnt/HC_VOL/repo && \
    ln -s /mnt/HC_VOL/repo /home/gitea/repo
}

install_gitea() {
  info "Installing Gitea..." && \
    info "Installing prerequisites..." && \
    apt-get -y install git && \
    info "Creating Gitea directories..." && \
    mkdir -p /var/lib/gitea/{custom,data,log} && \
    chown -R gitea:gitea /var/lib/gitea/ && \
    chmod -R 750 /var/lib/gitea/ && \
    mkdir /etc/gitea && \
    chown root:gitea /etc/gitea && \
    chmod 750 /etc/gitea && \
    info "Installing Gitea binary..." && \
    wget https://dl.gitea.com/gitea/1.19.0/gitea-1.19.0-linux-amd64 && \
    wget https://dl.gitea.com/gitea/1.19.0/gitea-1.19.0-linux-amd64.sha256 && \
    if [ "$(cat gitea-1.19.0-linux-amd64.sha256 | sha256sum --check --status; echo $?)" = '0' ]; then
      info "Gitea checksum verified"
    else
      err "Gitea checksum incorrect"
      err "Terminating script..."
      exit 1
    fi
    mv gitea-1.19.0-linux-amd64 /usr/local/bin/gitea && \
    chmod +x /usr/local/bin/gitea && \
    if ! command_exist "gitea"; then
      err "Gitea not found after installation"
      err "Terminating script..."
    else
      info "Gitea installed"
    fi
}

configure_gitea() {
  info "Configuring Gitea..." && \
    info "Installing Gitea service..." && \
    cat > /etc/systemd/system/gitea.service <<EOF
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target

[Service]
# Uncomment the next line if you have repos with lots of files and get a HTTP 500 error because of that
# LimitNOFILE=524288:524288
RestartSec=2s
Type=simple
User=gitea
Group=gitea
WorkingDirectory=/var/lib/gitea/
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=gitea HOME=/home/gitea GITEA_WORK_DIR=/var/lib/gitea

[Install]
WantedBy=multi-user.target
EOF

  info "Generating Gitea secrets..." && \
    GITEA_INT_TOKEN=$(gitea generate secret INTERNAL_TOKEN) && \
    GITEA_JWT_SECRET=$(gitea generate secret JWT_SECRET) && \
    GITEA_SECRET_KEY=$(gitea generate secret SECRET_KEY) && \
    cat > /etc/gitea/app.ini <<EOF
APP_NAME = Codec
RUN_USER = gitea
RUN_MODE = prod

[oauth2]
JWT_SECRET = $GITEA_JWT_SECRET

[security]
INTERNAL_TOKEN      = $GITEA_INT_TOKEN
INSTALL_LOCK        = true
SECRET_KEY          = $GITEA_SECRET_KEY
MIN_PASSWORD_LENGTH = 12
PASSWORD_COMPLEXITY = lower, upper, digit

[database]
DB_TYPE  = mysql
HOST     = 127.0.0.1:3306
NAME     = gitea
USER     = gitea
PASSWD   = password
SSL_MODE = disable
CHARSET  = utf8mb4
LOG_SQL  = false

[repository]
ROOT = /home/gitea/repo

[server]
SSH_DOMAIN       = git.kuanhong.org
DOMAIN           = git.kuanhong.org
HTTP_PORT        = 3000
ROOT_URL         = https://codec.kuanhong.org/
DISABLE_SSH      = true
LFS_START_SERVER = false
OFFLINE_MODE     = true

[mailer]
ENABLED        = true
MAILER_TYPE    = smtp
HOST           = email-smtp.ap-southeast-1.amazonaws.com:587
IS_TLS_ENABLED = false
FROM           = gitea-noreply@kuanhong.org
USER           = 
PASSWD         = 
SUBJECT_PREFIX = [Gitea] 

[service]
REGISTER_EMAIL_CONFIRM            = false
REGISTER_MANUAL_CONFIRM           = true
ENABLE_NOTIFY_MAIL                = false
DISABLE_REGISTRATION              = true
ALLOW_ONLY_EXTERNAL_REGISTRATION  = false
ENABLE_CAPTCHA                    = false
REQUIRE_SIGNIN_VIEW               = true
DEFAULT_KEEP_EMAIL_PRIVATE        = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING       = true
ENABLE_BASIC_AUTHENTICATION       = false
NO_REPLY_ADDRESS                  = codec.kuanhong.org

[api]
ENABLE_SWAGGER = false

[picture]
DISABLE_GRAVATAR        = true
ENABLE_FEDERATED_AVATAR = false

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[session]
PROVIDER = file

[log]
ROOT_PATH            = /var/lib/gitea/log
MODE                 = console,file
LEVEL                = info
REDIRECT_MACARON_LOG = true
MACARON              = console,file
ROUTER               = console,file
ENABLE_ACCESS_LOG    = true
ACCESS               = file

[log.console]
COLORIZE = false

[log.file]
LOG_ROTATE     = true
MAX_SIZE_SHIFT = 28
DAILY_ROTATE   = true
MAX_DAYS       = 90
COMPRESS       = true

[other]
SHOW_FOOTER_VERSION            = false
SHOW_FOOTER_TEMPLATE_LOAD_TIME = false
EOF

  info "Protecting Gitea configuration file ..." && \
    chown root:gitea /etc/gitea/app.ini && \
    chmod 640 /etc/gitea/app.ini && \
    info "Starting Gitea service ..." && \
    systemctl daemon-reload && \
    systemctl enable gitea && \
    systemctl start gitea && \
    systemctl status gitea --no-pager && \
    if ! service_active gitea; then
      warn "Gitea service is not running"
    else
      info "Gitea configured and started"
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
    info "Copying caddy binary..." && \
    cp caddy/linux/2.6.4/caddy-cloudflare-layer4-l4tls-l4proxy-security /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    info "Setting permissions..." && \
    chown caddy:caddy /usr/bin/caddy && \
    chown -R caddy:caddy /etc/caddy && \
    chown -R caddy:caddy /var/log/caddy && \
    chown -R caddy:caddy /var/lib/caddy && \
    info "Creating caddy service files..." && \
    cp caddy/caddy.service /lib/systemd/system/caddy.service && \
    cp caddy/caddy-api.service /lib/systemd/system/caddy-api.service && \
    systemctl daemon-reload && \
    info "Setting up caddy bash completion..." && \
    /usr/bin/caddy completion bash | sudo tee /etc/bash_completion.d/caddy && \
    info "Setting up caddy man pages..." && \
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
            "layer4.matchers.tls"
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
                      "${TELEPORT_PUBLIC_ADDR}"
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

install_fail2ban() {
  info "Installing fail2ban..." && \
    apt-get -y install fail2ban && \
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
    systemctl status fail2ban --no-pager && \
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
    apt install kopia && \
    if ! command_exist "kopia"; then
      err "kopia not found after installation"
      err "Terminating script..."
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
    systemctl status kopia --no-pager && \
    if ! service_active kopia; then
      warn "kopia service is not running"
    else
      info "kopia configured and started"
    fi
}

install_cron() {
  info "Install cron jobs..."
  if [ "$(crontab teleport.cron; echo $?)" = '0' ]; then
    info "Cron installed successfully"
  else
    warn "Failed to install cron jobs"
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
  install_fail2ban
  configure_fail2ban
  install_kopia
  configuring_kopia
  install_cron
}

main

} # this ensures the entire script is downloaded #