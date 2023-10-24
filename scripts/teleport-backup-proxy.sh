#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/teleport.conf" || fatal_err "${SCRIPT_PATH}/conf/teleport.conf is missing"

# set variables
backup_time=$(date "+%y%m%d_%H%M%S")
backup_dir=${TELEPORT_BACKUP_DIR}/${backup_time}_manual

setup_backup_dir() {
  info "Setting up backup directory..." && \
    mkdir -p ${backup_dir}
}

export_teleport_conf() {
  if [ ! -f /etc/teleport.yaml ]; then
    fatal_err "/etc/teleport.yaml is missing";
  fi

  info "Exporting Teleport configuration..." && \
    cp /etc/teleport.yaml ${backup_dir}/teleport_conf.yaml
}

export_teleport_state() {
  info "Checking Teleport service..." && \
    if ! service_active teleport; then
      fatal_err "Teleport service is not running"
    else
      info "Exporting Teleport state..."
      tctl get all --with-secrets > ${backup_dir}/teleport_state.yaml
    fi
}

stop_teleport_service() {
  info "Stopping Teleport service..." && \
    systemctl stop teleport
}

export_teleport_data() {
  if [ ! -d /var/lib/teleport ]; then
    fatal_err "/var/lib/teleport is missing";
  fi

  if service_active teleport; then
    fatal_err "Teleport service is still running"
  else
    info "Exporting Teleport data directory..."
    cd /var/lib
    tar cf ${backup_dir}/teleport_data_dir.tar teleport
  fi
}

export_caddy_conf() {
  if [ ! -f /etc/caddy/caddy.json ]; then
    fatal_err "/etc/caddy/caddy.json is missing";
  fi

  info "Exporting caddy configuration..." && \
    cp /etc/caddy/caddy.json ${backup_dir}/caddy.json
}

export_caddy_data() {
  if [ ! -d /var/lib/caddy/.local ]; then
    fatal_err "/var/lib/caddy/.local is missing";
  fi

  info "Exporting Caddy data directory..." && \
    cd /var/lib/caddy && \
    tar cf ${backup_dir}/caddy_data_dir.tar .local
}

export_kopia_config() {
  if [ ! -d /opt/kopia ]; then
    fatal_err "/opt/kopia is missing";
  fi

  info "Exporting kopia config directory..."
  cd /opt
  tar cf ${backup_dir}/kopia_opt_dir.tar kopia
}

setup_backup_dir
export_teleport_conf
export_teleport_state
stop_teleport_service
export_teleport_data
export_caddy_conf
export_caddy_data
export_kopia_config

} # this ensures the entire script is downloaded #