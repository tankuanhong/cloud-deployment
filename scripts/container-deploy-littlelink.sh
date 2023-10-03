#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_littlelink() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/littlelink.yaml" && \
    info "Deploying littlelink..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/littlelink.yaml"
}

setup_littlelink() {
  info "Cloning git repository into container..."
}

deploy_littlelink

} # this ensures the entire script is downloaded #