#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_changedetection() {
  info "Setting custom changedetection.io parameters..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/changedetection.yaml" && \
    info "Deploying changedetection.io..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/changedetection.yaml" && \
    info "Waiting for changedetection.io to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${CHANGEDETECTION_LABEL}"
}

patch_ingress() {
  info "Patching changedetection.io ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" | envsubst '$CHANGEDETECTION_LABEL,$CHANGEDETECTION_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${CHANGEDETECTION_LABEL} --patch-file "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml"
}

deploy_changedetection
patch_ingress

} # this ensures the entire script is downloaded #