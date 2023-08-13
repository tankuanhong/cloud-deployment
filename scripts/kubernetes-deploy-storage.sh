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
    sed -i "s@\"\"@nfs://${KUBE_MASTER}:/mnt/longhorn@g" ${SCRIPT_PATH}/backup-target.yaml && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/backup-target.yaml || fatal_err "Failed to set longhorn backup-target"

  info "Configuring hourly backup of volumes..." && \
    microk8s kubectl apply -f ${SCRIPT_PATH}/kubernetes/longhorn-hourly-backup.yaml || fatal_err "Failed to set longhorn hourly backup"
}

install_nfs_server() {
  info "Installing NFS server..." && \
    apt update && \
    apt -y install nfs-kernel-server

  if ! service_active nfs-kernel-server; then
    fatal_err "Failed to start NFS server"
  else
    info "NFS server installed and running"
  fi
}

configure_nfs_server() {
  info "Configuring NFS server..." && \
    mkdir -p "/mnt/longhorn" && \
    chown nobody:nogroup "/mnt/longhorn" && \
    echo "/mnt/longhorn    ${KUBE_INT_NET}(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports && \
    systemctl restart nfs-kernel-server

  if ! service_active nfs-kernel-server; then
    fatal_err "Failed to start NFS server"
  else
    info "nfs server configured"
  fi
}

install_longhorn
configure_longhorn
install_nfs_server
configure_nfs_server

} # this ensures the entire script is downloaded #