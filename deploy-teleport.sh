#!/bin/bash

{ # this ensures the entire script is downloaded #

# import log library and set options
source "${BASH_SOURCE%/*}/shell-logger/shell-logger"
LOGGER_LEVEL=0
LOGGER_ERROR_TRACE=0
LOGGER_STDERR_LEVEL=4
LOGGER_COLOR=auto
LOGGER_TARGET=deploy.log

# function to check if command exist
script_has() {
  type "$1" > /dev/null 2>&1
}

configure_ufw() {
  if [ "$(ufw status | grep -qw inactive >/dev/null 2>/dev/null; echo $?)" = '1' ] || [ "$(ufw show added | grep -qw None >/dev/null 2>/dev/null; echo $?)" = '1' ]; then
    warn "This server have pending firewall rules or ufw is already enabled." && \
      warn "Resetting ufw to default..." && \
      ufw --force disable && \
      ufw --force reset && \
      info "Reset completed."
  fi
  info "Configuring ufw..." && \
    sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw && \
    ufw default deny incoming && \
    ufw default allow outgoing && \
    ufw allow 22/tcp comment 'Default SSH' && \
    ufw allow 59222/tcp comment 'SSH' && \
    info "Enabling ufw..." && \
    ufw --force enable && \
    info "Firewall configured and enabled."
}


} # this ensures the entire script is downloaded #