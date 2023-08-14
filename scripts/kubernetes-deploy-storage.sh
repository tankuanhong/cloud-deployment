#!/bin/bash

{ # this ensures the entire script is downloaded #

# load configuration
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

install_longhorn() {
  info "Installing longhorn..." && \
    microk8s helm3 repo add longhorn https://charts.longhorn.io && \
    microk8s helm3 repo update && \
    microk8s kubectl create namespace longhorn-system && \
    microk8s helm3 install longhorn longhorn/longhorn \
      --namespace longhorn-system \
      --set defaultSettings.defaultDataPath="/longhorn" \
      --set csi.kubeletRootDir="/var/snap/microk8s/common/var/lib/kubelet" || fatal_err "Failed to install longhorn"

  sleep 60
  wait_for_pods_ready "300" "longhorn-system"
}

configure_longhorn() {
  info "Setting node-down-pod-deletion-policy" && \
    microk8s kubectl get settings node-down-pod-deletion-policy -n longhorn-system -o yaml > ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml && \
    sed -i 's/do-nothing/delete-both-statefulset-and-deployment-pod/g' ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml || fatal_err "Failed to set longhorn node-down-pod-deletion-policy"

  info "Setting allow-recurring-job-while-volume-detached" && \
    microk8s kubectl get settings allow-recurring-job-while-volume-detached -n longhorn-system -o yaml > ${SCRIPT_PATH}/allow-recurring-job-while-volume-detached.yaml && \
    sed -i 's/false/true/g' ${SCRIPT_PATH}/allow-recurring-job-while-volume-detached.yaml && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/allow-recurring-job-while-volume-detached.yaml || fatal_err "Failed to set longhorn allow-recurring-job-while-volume-detached"

  info "Setting backup-target" && \
    microk8s kubectl get settings backup-target -n longhorn-system -o yaml > ${SCRIPT_PATH}/backup-target.yaml && \
    sed -i "s@\"\"@nfs://${KUBE_NODE_1}:/mnt/longhorn@g" ${SCRIPT_PATH}/backup-target.yaml && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/backup-target.yaml || fatal_err "Failed to set longhorn backup-target"

  info "Configuring hourly backup of volumes..." && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/kubernetes/longhorn-hourly-backup.yaml || fatal_err "Failed to set longhorn hourly backup"
}

install_nfs_server() {
  info "Installing NFS server..." && \
    apt update && \
    apt -y install nfs-kernel-server || fatal_err "Failed to install nfs server"

  if ! service_active nfs-kernel-server; then
    fatal_err "Failed to start NFS server"
  else
    info "NFS server installed and running"
  fi
}

configure_nfs_server() {
  info "Configuring NFS server..." && \
    mkdir -p "${NFS_MOUNT_PATH}/longhorn" && \
    chown nobody:nogroup "${NFS_MOUNT_PATH}/longhorn" && \
    echo "${NFS_MOUNT_PATH}/longhorn  ${KUBE_INT_NET}(rw,sync,no_subtree_check)  ${KUBE_POD_NET}(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports || fatal_err "Failed to configure nfs server"
    
  systemctl restart nfs-kernel-server
  if ! service_active nfs-kernel-server; then
    fatal_err "Failed to start NFS server"
  else
    info "nfs server configured"
  fi
}

install_kopia() {
  info "Installing kopia..." && \
    curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /usr/share/keyrings/kopia-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list && \
    apt update && \
    apt -y install kopia

  if ! command_exist "kopia"; then
    fatal_err "Failed to install kopia"
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
  if [ "$(/usr/bin/kopia repository connect s3 --endpoint="${KOPIA_S3_URL}" --region="${KOPIA_REGION}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
    warn "Error connecting or repository not initialized"
    if ${KOPIA_REPO_INIT}; then
      info "Attempting to initialize repository"
      if [ "$(/usr/bin/kopia repository create s3 --endpoint="${KOPIA_S3_URL}" --region="${KOPIA_REGION}" --bucket="${KOPIA_S3_BUCKET}" --access-key="${KOPIA_S3_KEY}" --secret-access-key="${KOPIA_S3_SECRET}" --password="${KOPIA_REPO_PASSWORD}" --cache-directory="${KOPIA_CACHE_PATH}" --config-file="${KOPIA_CONFIG_PATH}"; echo $?)" != '0' ]; then
        warn "Unable to initialize repository"
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
    fatal_err "Failed to start kopia service"
  else
    info "kopia configured and started"
  fi
}

install_longhorn
configure_longhorn
install_nfs_server
configure_nfs_server
install_kopia
configure_kopia

} # this ensures the entire script is downloaded #