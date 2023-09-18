#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_memos() {
  info "Setting custom memos parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/memos.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/memos.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/memos.yaml" && \
    info "Deploying memos..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/memos.yaml" && \
    info "Waiting for memos to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${MEMOS_LABEL}"
}

deploy_memos

} # this ensures the entire script is downloaded #