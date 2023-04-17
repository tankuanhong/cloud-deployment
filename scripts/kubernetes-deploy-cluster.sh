#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit

install_pssh() {
  info "Installing pssh..." && \
    apt-get -y install pssh
}

deploy_master() {
  info "Deploying master node" && \
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-master.sh" || exit
}

copy_files_to_workers() {
  info "Copying scripts to kubernetes workers..." && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/shell-logger/shell-logger /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/conf/common.conf /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/conf/kubernetes.conf /root/ && \
    parallel-scp -H "${KUBE_WORKER_1} ${KUBE_WORKER_2} ${KUBE_WORKER_3}" -l root -O "StrictHostKeyChecking=no" ${SCRIPT_PATH}/scripts/kubernetes-deploy-worker.sh /root/
}

install_pssh
deploy_master
copy_files_to_workers

} # this ensures the entire script is downloaded #