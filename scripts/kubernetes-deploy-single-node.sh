#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit

req_check_master() {
  info "Checking no. of CPU cores..." && \
    if [ $(nproc) -lt "2" ]; then
      err "Kubernetes master does not meet min CPU requirement of 2"
      exit 1
    else
      info "Kubernetes master meets min CPU requirement of 2"
    fi
}

deploy_master() {
  info "Deploying master node..." && \
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-master.sh" && \
    touch "${SCRIPT_PATH}/master_rebooted" && \
    info "Rebooting master node..." && \
    info "Rerun start.sh upon master node startup" && \
    reboot
}

init_master() {
  info "Initializing master node..." && \
    source "${SCRIPT_PATH}/scripts/kubernetes-init-master.sh"
}

install_longhorn() {
  info "Installing prerequisites..." && \
    apt-get update && \
    apt-get -y install nfs-common && \
    systemctl enable iscsid && \
    systemctl start iscsid
  
  info "Disable multipathd for longhorn on master node..." && \
    cat <<EOF | sudo tee -a /etc/multipath.conf
blacklist {
    devnode "^sd[a-z0-9]+"
}
EOF
  systemctl restart multipathd

  info "Running longhorn installation check script on master node..." && \
    apt-get update && \
    apt-get -y install jq && \
    wget -O ${SCRIPT_PATH}/longhorn_environment_check.sh https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/scripts/environment_check.sh && \

  if /bin/bash ${SCRIPT_PATH}/longhorn_environment_check.sh; then
    info "Longhorn environment check passed"
  else
    err "Longhorn environment check failed"
    exit 1
  fi

  info "Installing longhorn..." && \
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/deploy/longhorn.yaml && \
    info "Waiting for longhorn pods to be ready..."
    kubectl wait pods -n longhorn-system --all --for condition=Ready --timeout=120s
  
  info "Printing longhorn web ui service address..." && \
    kubectl get svc longhorn-frontend -n longhorn-system
}

req_check_master
if [ -f "${SCRIPT_PATH}/master_rebooted" ]; then
  init_master
  install_longhorn
else
  deploy_master
fi

} # this ensures the entire script is downloaded #