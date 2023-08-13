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

configure_microk8s() {
  info "Configuring microk8s addons..." && \
    microk8s enable dashboard && \
    microk8s enable ingress || fatal_err "Failed to enable microk8s addons"
}

install_microk8s
#configure_microk8s

} # this ensures the entire script is downloaded #