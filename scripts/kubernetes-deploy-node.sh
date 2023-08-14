#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/scripts/common-functions.sh" || source "common-functions.sh" || { echo "common-functions.sh is missing"; exit 1; }

# load configuration
source "${SCRIPT_PATH}/conf/kubernetes.conf" || source "kubernetes.conf" || fatal_err "kubernetes.conf is missing"

install_microk8s() {
  info "Installing microk8s via snap..." && \
    snap install microk8s --classic --channel=${KUBE_VERSION} && \
    info "microk8s installation completed" || fatal_err "Failed to install microk8s"

  wait_for_node_ready "300"
}

update_hosts_file() {
  info "Adding all node hostnames to hosts file..."

  for ip in "${KUBE_NODE_1}" "${KUBE_NODE_2}" "${KUBE_NODE_3}"; do
    hostname=$(ssh -o StrictHostKeyChecking=accept-new -q -p "${SSH_PORT}" "${ip}" hostname)
    if [ $? -eq 0 ]; then
      echo "${ip} ${hostname}" >> /etc/hosts || fatal_err "Failed to add ${ip} to /etc/hosts on ${KUBE_NODE_1}"
      PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2} -S "echo ${ip} ${hostname} >> /etc/hosts" || fatal_err "Failed to add ${ip} to /etc/hosts on ${KUBE_NODE_2}"
      PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_3} -S "echo ${ip} ${hostname} >> /etc/hosts" || fatal_err "Failed to add ${ip} to /etc/hosts on ${KUBE_NODE_3}"
    else
      fatal_err "Failed to retrieve hostname for ${ip}"
    fi
  done
}

install_microk8s
update_hosts_file

} # this ensures the entire script is downloaded #