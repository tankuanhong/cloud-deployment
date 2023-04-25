#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit

install_parallel_utilities() {
  info "Installing pssh and pdsh..." && \
    apt-get -y install pssh pdsh
}

deploy_master() {
  info "Deploying master node" && \
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-master.sh" || exit
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
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=no" pdsh -w ${KUBE_WORKER_1},${KUBE_WORKER_2},${KUBE_WORKER_3} "kubeadm join ${KUBE_MASTER}:6443 --token $(kubeadm token list -o=jsonpath='{$.token}') --discovery-token-ca-cert-hash sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
}

install_parallel_utilities
deploy_master
generate_ssh_key
copy_files_to_workers
deploy_workers

} # this ensures the entire script is downloaded #