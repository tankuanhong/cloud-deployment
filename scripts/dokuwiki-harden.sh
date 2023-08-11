#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/dokuwiki.conf" || { err "${SCRIPT_PATH}/conf/dokuwiki.conf is missing"; exit 1; }

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

check_dokuwiki_install() {
  clear
  echo -ne "
[Dokuwiki Post-Install Configuration]

Go to https://${DOKUWIKI_DOMAIN}/install.php and complete the setup form.
Wait for this script to finish before logging in to Dokuwiki.

"
  until test -f "/var/www/dokuwiki/conf/local.php"; do warn "Waiting for Dokuwiki setup to complete..." && sleep 10; done
}

harden_dokuwiki() {
  info "Hardening Dokuwiki installation..." && \
    info "Adding install.php to blocked files..." && \
    sed -i '/"\/vendor\/\*",/a \                            "/install.php",' /etc/caddy/caddy.json && \
    info "Setting baseurl for correct redirection..." && \
    sed -i "/conf.*license/a\$conf['baseurl'] = 'https://${DOKUWIKI_DOMAIN}';" /var/www/dokuwiki/conf/local.php && \
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
  
  systemctl restart caddy && \
   systemctl status caddy --no-pager
  
  if ! service_active caddy; then
    warn "caddy service is not running"
  else
    info "caddy restarted"
  fi

  info "Hardening script completed. You can begin to use Dokuwiki."
}

check_dokuwiki_install
harden_dokuwiki

} # this ensures the entire script is downloaded #