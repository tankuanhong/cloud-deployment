#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating FIREFLY3_DB_ROOT_PASSWORD..." && \
    export FIREFLY3_DB_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating FIREFLY3_DB_PASSWORD..." && \
    export FIREFLY3_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/firefly3-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/firefly3-db.yaml"
}

deploy_firefly3() {
  info "Setting custom firefly-iii parameters..." && \
    info "Generating FIREFLY3_APP_KEY..." && \
    export FIREFLY3_APP_KEY=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/firefly3.yaml" && \
    info "Deploying firefly-iii..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/firefly3.yaml"
}

patch_ingress() {
  info "Patching firefly3 ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/firefly3-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/firefly3-ing-patch.yaml" | envsubst '$FIREFLY3_LABEL,$FIREFLY3_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/firefly3-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${FIREFLY3_LABEL} --patch-file "${SCRIPT_PATH}/kubernetes/firefly3-ing-patch.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "FIREFLY3_DB_ROOT_PASSWORD: ${FIREFLY3_DB_ROOT_PASSWORD}"
  info "FIREFLY3_DB_PASSWORD: ${FIREFLY3_DB_PASSWORD}"
  info "Please verify that 2 credentials are printed."
}

deploy_database
deploy_firefly3
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #