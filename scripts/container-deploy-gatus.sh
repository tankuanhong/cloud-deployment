#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_gatus() {
  info "Setting custom gatus parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/gatus.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/gatus.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/gatus.yaml" && \
    info "Deploying gatus..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/gatus.yaml" && \
    info "Waiting for gatus to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${GATUS_LABEL}"
}

deploy_gatus

} # this ensures the entire script is downloaded #