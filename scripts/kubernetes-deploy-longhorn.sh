#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit

install_prereq() {
  info "Installing prerequisites on master node..." && \
    apt-get update && \
    apt-get -y install nfs-common && \
    systemctl enable iscsid && \
    systemctl start iscsid
  
  info "Installing prerequisites on worker nodes..." && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "apt-get update && apt-get -y install nfs-common && systemctl enable iscsid && systemctl start iscsid"
}

configure_multipathd() {
  info "Disable multipathd for longhorn on master node..." && \
    cat <<EOF | sudo tee -a /etc/multipath.conf
blacklist {
    devnode "^sd[a-z0-9]+"
}
EOF
  systemctl restart multipathd

  info "Disable multipathd for longhorn on worker nodes..." && \
    parallel-scp -H "${KUBE_WORKER_1}:${SSH_PORT} ${KUBE_WORKER_2}:${SSH_PORT} ${KUBE_WORKER_3}:${SSH_PORT}" -l root -O "StrictHostKeyChecking=no" /etc/multipath.conf /etc/multipath.conf && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "systemctl restart multipathd"
}

longhorn_preflight() {
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
}

install_longhorn() {
  info "Installing longhorn..." && \
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${LONGHORN_VERSION}/deploy/longhorn.yaml && \
    info "Waiting for longhorn pods to be ready..."
    kubectl wait pods -n longhorn-system --all --for condition=Ready --timeout=120s
}

configure_longhorn() {
  info "Setting node-down-pod-deletion-policy" && \
    kubectl get settings node-down-pod-deletion-policy -n longhorn-system -o yaml > ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml && \
    sed -i 's/do-nothing/delete-both-statefulset-and-deployment-pod/g' ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml && \
    kubectl apply -f ${SCRIPT_PATH}/node-down-pod-deletion-policy.yaml
}

show_longhorn_ui_svc() {
  info "Printing longhorn web ui service address..." && \
    kubectl get svc longhorn-frontend -n longhorn-system
}

install_prereq
configure_multipathd
longhorn_preflight
install_longhorn
configure_longhorn
show_longhorn_ui_svc

} # this ensures the entire script is downloaded #