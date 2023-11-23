#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

# create directory to store deployed yaml
mkdir -p "${SCRIPT_PATH}/deployed"

wait_for_node_ready "300"

create_changedetection_pvc() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/changedetection/changedetection-pvc.yaml" "${SCRIPT_PATH}/deployed/changedetection-pvc.yaml" && \
    info "Creating changedetection pvc..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/deployed/changedetection-pvc.yaml"
}

deploy_changedetection() {
  info "Setting custom changedetection.io parameters..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/changedetection/changedetection.yaml" "${SCRIPT_PATH}/deployed/changedetection.yaml" && \
    info "Deploying changedetection.io..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/deployed/changedetection.yaml"
}

patch_ingress() {
  info "Patching changedetection.io ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/changedetection/changedetection-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/changedetection/changedetection-ing-patch.yaml" | envsubst '$CHANGEDETECTION_LABEL,$CHANGEDETECTION_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/deployed/changedetection-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${CHANGEDETECTION_LABEL} --patch-file "${SCRIPT_PATH}/deployed/changedetection-ing-patch.yaml"
}

create_changedetection_pvc
deploy_changedetection
patch_ingress

} # this ensures the entire script is downloaded #