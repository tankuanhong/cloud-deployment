#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_templateapp() {
  info "Setting custom templateapp parameters..." && \
    info "Generating TEMPLATEAPP_PARAMETER_1..." && \
    export TEMPLATEAPP_PARAMETER_1=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/zz-templateapp.yaml" && \
    info "Deploying app..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/zz-templateapp.yaml"
}

patch_ingress() {
  info "Patching templateapp ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/zz-templateapp-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/zz-templateapp-ing-patch.yaml" | envsubst '$TEMPLATEAPP_LABEL,$TEMPLATEAPP_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/zz-templateapp-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${TEMPLATEAPP_LABEL} --patch-file "${SCRIPT_PATH}/kubernetes/zz-templateapp-ing-patch.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "TEMPLATEAPP_PARAMETER_1: ${TEMPLATEAPP_PARAMETER_1}"
  info "Please verify that 1 credential are printed."
}

deploy_templateapp
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #