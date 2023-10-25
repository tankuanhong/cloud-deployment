#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || fatal_err "${SCRIPT_PATH}/conf/teleport.conf is missing"

check_restore_files() {
  if [ ! -f "${SCRIPT_PATH}/${TELEPORT_CONF_RESTORE}" ]; then fatal_err "${SCRIPT_PATH}/${TELEPORT_CONF_RESTORE} is missing"; fi
  if [ ! -f "${SCRIPT_PATH}/${TELEPORT_STATE_RESTORE}" ]; then fatal_err "${SCRIPT_PATH}/${TELEPORT_STATE_RESTORE} is missing"; fi
  if [ ! -f "${SCRIPT_PATH}/${TELEPORT_DATA_RESTORE}" ]; then fatal_err "${SCRIPT_PATH}/${TELEPORT_DATA_RESTORE} is missing"; fi
  if [ ! -f "${SCRIPT_PATH}/${CADDY_CONF_RESTORE}" ]; then fatal_err "${SCRIPT_PATH}/${CADDY_CONF_RESTORE} is missing"; fi
  if [ ! -f "${SCRIPT_PATH}/${CADDY_DATA_RESTORE}" ]; then fatal_err "${SCRIPT_PATH}/${CADDY_DATA_RESTORE} is missing"; fi
}

restore_caddy_data() {
  info "Restoring Caddy data directory..." && \
    mkdir /var/lib/caddy && \
    mv ${SCRIPT_PATH}/${CADDY_DATA_RESTORE} /var/lib/caddy && \
    cd /var/lib/caddy && \
    tar xf ${CADDY_DATA_RESTORE} && \
    rm -f ${CADDY_DATA_RESTORE}
}

deploy_teleport_proxy() {
  source "${SCRIPT_PATH}/scripts/teleport-deploy-proxy.sh"
}

stop_caddy_service() {
  info "Stopping caddy service..." && \
    systemctl stop caddy
}

restore_caddy_conf() {
  info "Restoring Caddy configuration..." && \
    mv ${SCRIPT_PATH}/${CADDY_CONF_RESTORE} /etc/caddy/caddy.json
}

stop_teleport_service() {
  info "Stopping Teleport service..." && \
    systemctl stop teleport
}

restore_teleport_conf() {
  info "Restoring Teleport configuration..." && \
    mv ${SCRIPT_PATH}/${TELEPORT_CONF_RESTORE} /etc/teleport.yaml
}

restore_teleport_data() {
  info "Restoring Teleport data directory..." && \
    mv ${SCRIPT_PATH}/${TELEPORT_DATA_RESTORE} /var/lib && \
    cd /var/lib && \
    rm -rf teleport && \
    tar xf ${TELEPORT_DATA_RESTORE} && \
    rm -f ${TELEPORT_DATA_RESTORE}
}

restore_kopia_data() {
  info "Checking for kopia restore file..." && \
    if [ ! -f "${SCRIPT_PATH}/${KOPIA_CONF_RESTORE}" ]; then
      warn "${SCRIPT_PATH}/${KOPIA_CONF_RESTORE} is missing"
      warn "Skipping kopia configuration restore"
    else
      info "Restoring kopia config directory..."
      systemctl stop kopia
      mv ${SCRIPT_PATH}/${KOPIA_CONF_RESTORE} /opt
      cd /opt
      rm -rf kopia
      tar xf ${KOPIA_CONF_RESTORE}
      rm -f ${KOPIA_CONF_RESTORE}
      info "kopia config restored"
      systemctl start kopia
    fi
}

start_caddy_service() {
  info "Starting caddy service..." && \
    systemctl start caddy
}

restore_teleport_state() {
  info "Restoring Teleport state..."
  teleport start --config /etc/teleport.yaml --bootstrap ${SCRIPT_PATH}/${TELEPORT_STATE_RESTORE} &
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
stop_caddy_service
restore_caddy_conf
stop_teleport_service
restore_teleport_conf
restore_teleport_data
restore_kopia_data
start_caddy_service
restore_teleport_state

} # this ensures the entire script is downloaded #