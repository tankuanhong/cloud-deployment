#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

install_parallel_utilities() {
  info "Installing pssh and pdsh..." && \
    apt-get update && \
    apt-get -y install pssh pdsh || fatal_err "Failed to install pssh and pdsh"
}

generate_ssh_keypair() {
  info "Generating ssh keypair..." && \
    ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" && \
    info "Copy and run the following command manually on all nodes:" && \
    info "" && \
    info "mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 644 .ssh/authorized_keys && echo $(cat $HOME/.ssh/id_ed25519.pub) >> .ssh/authorized_keys" && \
    info ""

  read -p "Press enter to continue"

  wait_for_ssh_ready "300" "${KUBE_NODE_1}"
  wait_for_ssh_ready "300" "${KUBE_NODE_2}"
  wait_for_ssh_ready "300" "${KUBE_NODE_3}"
}

deploy_ssh_keypair() {
  info "Deploying ssh keypair..." && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root $HOME/.ssh/id_ed25519 /root/.ssh/id_ed25519 && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root $HOME/.ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub && \
    PDSH_RCMD_TYPE=ssh pdsh -w ${KUBE_NODE_2},${KUBE_NODE_3} -S "chmod 600 /root/.ssh/id_ed25519" && \
    PDSH_RCMD_TYPE=ssh pdsh -w ${KUBE_NODE_2},${KUBE_NODE_3} -S "chmod 644 /root/.ssh/id_ed25519.pub" || fatal_err "Failed to deploy ssh keypair"
}

harden_all_nodes() {
  info "Hardening all nodes..." && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root ${SCRIPT_PATH}/shell-logger/shell-logger /root/ && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root ${SCRIPT_PATH}/scripts/common-functions.sh /root/ && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root ${SCRIPT_PATH}/scripts/common-harden-ubuntu.sh /root/ && \
    parallel-scp -H "${KUBE_NODE_2} ${KUBE_NODE_3}" -l root ${SCRIPT_PATH}/conf/common.conf /root/ && \
    PDSH_RCMD_TYPE=ssh pdsh -w ${KUBE_NODE_2},${KUBE_NODE_3} -S "/bin/bash /root/common-harden-ubuntu.sh" && \
    source ${SCRIPT_PATH}/scripts/common-harden-ubuntu.sh || fatal_err "Failed to harden all nodes"
}

node_firewall_rules() {
  info "Allow all inter-node communications..." && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT} -o StrictHostKeyChecking=accept-new" pdsh -w ${KUBE_NODE_1},${KUBE_NODE_2},${KUBE_NODE_3} -S "ufw allow from ${KUBE_INT_NET} comment 'Inter-node communications'" || fatal_err "Failed to configure ufw for inter-node communications"
}

install_snapd() {
  info "Installing snapd on all nodes..." && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_1},${KUBE_NODE_2},${KUBE_NODE_3} -S "apt-get update && apt-get -y install snapd" || fatal_err "Failed to install snapd"
  
  info "Restarting other nodes..."
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2},${KUBE_NODE_3} -S "reboot"

  info "Sleep 1 minute for others nodes to reboot..." && \
    sleep 60 && \
    info "Wake after 1 minute"
  
  wait_for_ssh_ready "300" "${KUBE_NODE_2}" "${SSH_PORT}"
  wait_for_ssh_ready "300" "${KUBE_NODE_3}" "${SSH_PORT}"

  info "Rebooting current node..." && \
    touch "${SCRIPT_PATH}/rebooted" && \
    info "Rerun start.sh upon node startup" && \
    reboot
}

deploy_microk8s() {
  info "Deploying microk8s on all nodes..." && \
    parallel-scp -H "${KUBE_NODE_2}:${SSH_PORT} ${KUBE_NODE_3}:${SSH_PORT}" -l root ${SCRIPT_PATH}/scripts/kubernetes-deploy-node.sh /root/ && \
    parallel-scp -H "${KUBE_NODE_2}:${SSH_PORT} ${KUBE_NODE_3}:${SSH_PORT}" -l root ${SCRIPT_PATH}/conf/kubernetes.conf /root/ && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2},${KUBE_NODE_3} -S "/bin/bash /root/kubernetes-deploy-node.sh" && \
    source ${SCRIPT_PATH}/scripts/kubernetes-deploy-node.sh || fatal_err "Failed to deploy microk8s on all nodes"
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

set_node_ip() {
  info "Stopping microk8s..."
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_1},${KUBE_NODE_2},${KUBE_NODE_3} -S "microk8s stop" || fatal_err "Failed to stop microk8s"

  info "Appending --node-ip to kubelet config..."
  echo "--node-ip=${KUBE_NODE_1}" >> /var/snap/microk8s/current/args/kubelet || fatal_err "Failed to append --node-ip to ${KUBE_NODE_1}"
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2} -S "echo "--node-ip=${KUBE_NODE_2}" >> /var/snap/microk8s/current/args/kubelet" || fatal_err "Failed to append --node-ip to ${KUBE_NODE_2}"
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_3} -S "echo "--node-ip=${KUBE_NODE_3}" >> /var/snap/microk8s/current/args/kubelet" || fatal_err "Failed to append --node-ip to ${KUBE_NODE_3}"

  info "Appending --advertise-address to api server config..."
  echo "--advertise-address=${KUBE_NODE_1}" >> /var/snap/microk8s/current/args/kube-apiserver || fatal_err "Failed to append --advertise-address to ${KUBE_NODE_1}"
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2} -S "echo "--advertise-address=${KUBE_NODE_2}" >> /var/snap/microk8s/current/args/kube-apiserver" || fatal_err "Failed to append --advertise-address to ${KUBE_NODE_2}"
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_3} -S "echo "--advertise-address=${KUBE_NODE_3}" >> /var/snap/microk8s/current/args/kube-apiserver" || fatal_err "Failed to append --advertise-address to ${KUBE_NODE_3}"

  info "Starting microk8s..."
  PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_1},${KUBE_NODE_2},${KUBE_NODE_3} -S "microk8s start" || fatal_err "Failed to start microk8s"
}

join_nodes() {
  info "Joining all nodes..." && \
    invite=$(microk8s add-node | grep -m 1 -o "microk8s join .*${KUBE_NODE_1//./\\.}.*") && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_2} -S ${invite} && \
    invite=$(microk8s add-node | grep -m 1 -o "microk8s join .*${KUBE_NODE_1//./\\.}.*") && \
    PDSH_RCMD_TYPE=ssh PDSH_SSH_ARGS_APPEND="-p ${SSH_PORT}" pdsh -w ${KUBE_NODE_3} -S ${invite} || fatal_err "Failed to join nodes"
}

configure_microk8s() {
  info "Configuring microk8s addons..." && \
    microk8s enable dashboard && \
    microk8s enable ingress || fatal_err "Failed to enable microk8s addons"
}

deploy_storage() {
  info "Deploying storage services..." && \
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-storage.sh" || fatal_err "Failed to deploy storage services"
}

configure_nginx() {
  info "Configuring ingress nginx controller..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/ingress-custom-headers.yaml" && \
    microk8s kubectl -n ingress patch configmap nginx-load-balancer-microk8s-conf --patch-file "${SCRIPT_PATH}/kubernetes/nginx-load-balancer-microk8s-conf.yaml" || fatal_err "Failed to configure ingress nginx"
}

if [ -f "${SCRIPT_PATH}/rebooted" ]; then
  rm -f "${SCRIPT_PATH}/rebooted"
  deploy_microk8s
  update_hosts_file
  set_node_ip
  join_nodes
  configure_microk8s
  deploy_storage
  configure_nginx
else
  install_parallel_utilities
  generate_ssh_keypair
  deploy_ssh_keypair
  harden_all_nodes
  node_firewall_rules
  install_snapd
fi

} # this ensures the entire script is downloaded #