#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/teleport.conf" || exit

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

check_restore_files() {
  if [ ! -f "${TELEPORT_STATE_RESTORE}" ]; then exit 1; fi
  if [ ! -f "${TELEPORT_DATA_RESTORE}" ]; then exit 1; fi
  if [ ! -f "${CADDY_DATA_RESTORE}" ]; then exit 1; fi
}

restore_caddy_data() {
  info "Restoring Caddy data directory..." && \
    mkdir /var/lib/caddy && \
    mv ${CADDY_DATA_RESTORE} /var/lib/caddy && \
    cd /var/lib/caddy && \
    tar xf ${CADDY_DATA_RESTORE} && \
    rm -f ${CADDY_DATA_RESTORE}
}

deploy_teleport_proxy() {
  source "${SCRIPT_PATH}/scripts/teleport-deploy-proxy.sh"
}

stop_teleport_service() {
  info "Stopping Teleport service..." && \
    systemctl stop teleport
}

restore_teleport_data() {
  info "Restoring Teleport data directory..." && \
    mv ${TELEPORT_DATA_RESTORE} /var/lib && \
    cd /var/lib && \
    rm -rf teleport && \
    tar xf ${TELEPORT_DATA_RESTORE} && \
    rm -f ${TELEPORT_DATA_RESTORE}
}

restore_teleport_state() {
  info "Restoring Teleport state..."
  teleport start --config /etc/teleport.yaml --bootstrap ${TELEPORT_STATE_RESTORE} &
  TELEPORT_RESTORE_PID=$!
  info "Teleport started as background process with pid ${TELEPORT_RESTORE_PID}"
  info "Once restore is complete, verify that you can login to Teleport"
  info "Terminate the background Teleport process with kill -2 ${TELEPORT_RESTORE_PID}"
}

main() {
  check_restore_files
  restore_caddy_data
  deploy_teleport_proxy
  stop_teleport_service
  restore_teleport_data
  restore_teleport_state
}

main

} # this ensures the entire script is downloaded #