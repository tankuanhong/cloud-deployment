#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || fatal_err "${SCRIPT_PATH}/conf/teleport.conf is missing"

check_restore_files() {
  if [ ! -f "${TELEPORT_STATE_RESTORE}" ]; then fatal_err "${TELEPORT_STATE_RESTORE} is missing"; fi
  if [ ! -f "${TELEPORT_DATA_RESTORE}" ]; then fatal_err "${TELEPORT_DATA_RESTORE} is missing"; fi
  if [ ! -f "${CADDY_DATA_RESTORE}" ]; then fatal_err "${CADDY_DATA_RESTORE} is missing"; fi
}

restore_caddy_data() {
  info "Restoring Caddy data directory..." && \
    mkdir /var/lib/caddy && \
    mv ${CADDY_DATA_RESTORE} /var/lib/caddy && \
    cd /var/lib/caddy && \
    tar xf caddy_data_dir.tar && \
    rm -f caddy_data_dir.tar
}

deploy_teleport_proxy() {
  source "${SCRIPT_PATH}/scripts/teleport-deploy-proxy.sh"
}

stop_kopia_service() {
  info "Stopping kopia service..." && \
    systemctl stop kopia
}

restore_kopia_data() {
  info "Restoring kopia config directory..." && \
    mv ${KOPIA_CONFIG_RESTORE} /opt && \
    cd /opt && \
    rm -rf kopia && \
    tar xf kopia_opt_dir.tar && \
    rm -f kopia_opt_dir.tar && \
    info "kopia config restored"
    systemctl start kopia
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
    tar xf teleport_data_dir.tar && \
    rm -f teleport_data_dir.tar
}

restore_teleport_state() {
  info "Restoring Teleport state..."
  teleport start --config /etc/teleport.yaml --bootstrap ${TELEPORT_STATE_RESTORE} &
  TELEPORT_RESTORE_PID=$!
  info "Teleport started as background process with pid ${TELEPORT_RESTORE_PID}"
  info "After restore is complete, verify that you can login to Teleport"
  info "To terminate the background Teleport process, use the following command"
  info "kill -2 ${TELEPORT_RESTORE_PID}"
  info "After that, Teleport can started via service"
}

check_restore_files
restore_caddy_data
deploy_teleport_proxy
stop_kopia_service
restore_kopia_data
stop_teleport_service
restore_teleport_data
restore_teleport_state

} # this ensures the entire script is downloaded #