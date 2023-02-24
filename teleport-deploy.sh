#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${BASH_SOURCE%/*}/shell-logger/shell-logger" || exit
source "${BASH_SOURCE%/*}/deploy.conf" || exit


# function to check if command exist
script_has() {
  type "$1" > /dev/null 2>&1
}

if [ $(lsb_release -si) != "Ubuntu" ] || [ $(lsb_release -si) != "20.04" ]; then
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
    info "Enabling ufw..." && \
    ufw --force enable && \
    ufw status numbered && \
    info "Firewall configured and enabled"
}


} # this ensures the entire script is downloaded #