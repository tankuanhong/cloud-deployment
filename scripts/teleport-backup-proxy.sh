#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || fatal_err "${SCRIPT_PATH}/conf/teleport.conf is missing"

export_teleport_state() {
  info "Checking Teleport service..."
  if ! service_active teleport; then
    fatal_err "Teleport service is not running"
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
    fatal_err "Teleport service is still running"
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