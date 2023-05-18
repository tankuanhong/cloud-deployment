#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit

# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

install_kopia() {
  info "Installing kopia..." && \
    curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list && \
    apt update && \
    apt install kopia

  if ! command_exist "kopia"; then
    err "kopia not found after installation"
    err "Terminating script..."
    exit 1
  else
    info "kopia installed"
  fi
}

configure_kopia() {
  info "Configuring kopia..." && \
    cat > /etc/systemd/system/kopia.service <<EOF
[Unit]
Description=Kopia HTTP Server
Documentation=https://kopia.io/docs/reference/
After=basic.target network.target

[Service]
ExecStart=/usr/bin/kopia server start --address="${KOPIA_WEB_UI}" --insecure --without-password --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"
ExecStop=/usr/bin/kopia server shutdown
ExecReload=/usr/bin/kopia server refresh --address="${KOPIA_WEB_UI}"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  info "Connecting to backup repository..."
  if [ "$(/usr/bin/kopia repository connect s3 --endpoint="${KOPIA_S3_URL}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
    warn "Error connecting or repository not initialized"
    if ${KOPIA_REPO_INIT}; then
      info "Attempting to initialize repository"
      if [ "$(/usr/bin/kopia repository create s3 --endpoint="${KOPIA_S3_URL}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
        warn "Unable to connect to repository"
      else
        info "Repository initialized"
      fi
    else
      warn "Check repository credentials then manually connect through kopia Web UI"
    fi
  else
    info "Repository connected"
  fi

  info "Starting kopia service..." && \
    systemctl daemon-reload && \
    systemctl enable kopia && \
    systemctl start kopia && \
    systemctl status kopia --no-pager

  if ! service_active kopia; then
    warn "kopia service is not running"
  else
    info "kopia configured and started"
  fi
}

install_nfs_server() {
  info "Installing NFS server..." && \
    apt update && \
    apt -y install nfs-kernel-server

  if ! service_active nfs-kernel-server; then
    warn "nfs server is not running"
  else
    info "nfs server installed"
  fi
}

configure_nfs_server() {
  info "Configuring NFS server..." && \
    mkdir -p "${MOUNT_PATH}/longhorn" && \
    chown nobody:nogroup "${MOUNT_PATH}/longhorn" && \
    echo "${MOUNT_PATH}/longhorn    ${KUBE_INT_NET}(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports && \
    systemctl restart nfs-kernel-server

  if ! service_active nfs-kernel-server; then
    warn "nfs server is not running"
  else
    info "nfs server configured"
  fi
}

install_kopia
configure_kopia
install_nfs_server
configure_nfs_server

} # this ensures the entire script is downloaded #