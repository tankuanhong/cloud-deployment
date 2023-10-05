#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_discovery() {
  info "Setting custom syncthing discovery parameters..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" && \
    info "Deploying syncthing discovery..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml"
}

deploy_discovery

} # this ensures the entire script is downloaded #