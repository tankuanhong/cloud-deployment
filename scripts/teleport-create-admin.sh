#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || { err "${SCRIPT_PATH}/conf/teleport.conf is missing" >&2; exit 1; }

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

create_admin_user() {
  info "Checking Teleport service..."
  if ! service_active teleport; then
    err "Teleport service is not running"
    exit 1
  else
    info "Creating admin user"
    tctl users add ${TELEPORT_ADMIN_USER} --logins=root --roles=access,editor
  fi
}

create_admin_user

} # this ensures the entire script is downloaded #