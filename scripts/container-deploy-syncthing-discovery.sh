#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_discovery() {
  info "Setting custom syncthing discovery parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" && \
    info "Deploying syncthing discovery..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml"
}

patch_ingress() {
  info "Patching syncthing discovery ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/syncthing-discovery-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/syncthing-discovery-ing-patch.yaml" | envsubst '$ST_DISCOSRV_LABEL' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/syncthing-discovery-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${ST_DISCOSRV_LABEL} --patch-file "${SCRIPT_PATH}/kubernetes/syncthing-discovery-ing-patch.yaml"
}

deploy_discovery
patch_ingress

} # this ensures the entire script is downloaded #