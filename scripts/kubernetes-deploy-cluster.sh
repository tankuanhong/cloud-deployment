#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

req_check_master() {
  info "Checking no. of CPU cores..." && \
    if [ $(nproc) -lt "2" ]; then
      err "Kubernetes master does not meet min CPU requirement of 2"
      exit 1
    else
      info "Kubernetes master meets min CPU requirement of 2"
    fi
}

install_parallel_utilities() {
  info "Installing pssh and pdsh..." && \
    apt-get update && \
    apt-get -y install pssh pdsh
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

generate_ssh_key() {
  info "Generating ssh key on master node" && \
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" && \
    info "Run the following command manually at all the worker nodes:" && \
    info "" && \
    info "mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 644 .ssh/authorized_keys && echo $(cat $HOME/.ssh/id_ed25519.pub) > .ssh/authorized_keys" && \
    info ""

  read -p "Press enter to continue"

  until ssh -o StrictHostKeyChecking=no -q ${KUBE_WORKER_1} exit; do warn "Waiting for ${KUBE_WORKER_1}..." && sleep 10; done && \
  until ssh -o StrictHostKeyChecking=no -q ${KUBE_WORKER_2} exit; do warn "Waiting for ${KUBE_WORKER_2}..." && sleep 10; done && \
  until ssh -o StrictHostKeyChecking=no -q ${KUBE_WORKER_3} exit; do warn "Waiting for ${KUBE_WORKER_3}..." && sleep 10; done
}

copy_files_to_workers() {
  info "Copying scripts to kubernetes workers..." && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/shell-logger/shell-logger /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/conf/common.conf /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/conf/kubernetes.conf /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/scripts/kubernetes-deploy-worker.sh /root/
}

deploy_workers() {
  info "Deploying worker nodes" && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "/bin/bash /root/kubernetes-deploy-worker.sh" && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "reboot"

  info "Sleep 1 minute for worker nodes to reboot..." && \
  sleep 60 && \
  info "Wake after 1 minute"

  until ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -q ${KUBE_WORKER_1} exit; do warn "Waiting for ${KUBE_WORKER_1}..." && sleep 10; done && \
  until ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -q ${KUBE_WORKER_2} exit; do warn "Waiting for ${KUBE_WORKER_2}..." && sleep 10; done && \
  until ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -q ${KUBE_WORKER_3} exit; do warn "Waiting for ${KUBE_WORKER_3}..." && sleep 10; done

  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "kubeadm join ${KUBE_MASTER}:6443 --token $(kubeadm token list -o=jsonpath='{$.token}') --discovery-token-ca-cert-hash sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
}

req_check_master
if [ -f "${SCRIPT_PATH}/master_rebooted" ]; then
  init_master
  generate_ssh_key
  copy_files_to_workers
  deploy_workers
else
  install_parallel_utilities
  deploy_master
fi

} # this ensures the entire script is downloaded #