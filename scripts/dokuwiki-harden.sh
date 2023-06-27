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

harden_dokuwiki

} # this ensures the entire script is downloaded #