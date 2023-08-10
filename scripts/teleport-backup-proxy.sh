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

export_teleport_state() {
  info "Checking Teleport service..."
  if ! service_active teleport; then
    err "Teleport service is not running"
    exit 1
  else
    info "Exporting Teleport state"
    tctl get all --with-secrets > ${SCRIPT_PATH}/teleport_state_$(date "+%y%m%d_%H%M%S").yaml
  fi
}

stop_teleport_service() {
  info "Stopping Teleport service..."
  systemctl stop teleport
}

export_teleport_data() {
  if service_active teleport; then
    err "Teleport service is still running"
    exit 1
  else
    info "Exporting Teleport data directory..."
    cd /var/lib
    tar cf ${SCRIPT_PATH}/teleport_data_dir_$(date "+%y%m%d_%H%M%S").tar teleport
  fi
}

export_caddy_data() {
  info "Exporting Caddy data directory..."
  cd /var/lib/caddy
  tar cf ${SCRIPT_PATH}/caddy_data_dir_$(date "+%y%m%d_%H%M%S").tar .local
}

export_kopia_config() {
  info "Exporting kopia config directory..."
  cd /opt
  tar cf ${SCRIPT_PATH}/kopia_opt_dir_$(date "+%y%m%d_%H%M%S").tar kopia
}

export_teleport_state
stop_teleport_service
export_teleport_data
export_caddy_data
export_kopia_config

} # this ensures the entire script is downloaded #