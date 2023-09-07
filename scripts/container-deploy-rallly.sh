#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating RALLLY_DB_POSTGRES_PASSWORD..." && \
    export RALLLY_DB_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating RALLLY_DB_PASSWORD..." && \
    export RALLLY_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/rallly-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/rallly-db.yaml"
}

deploy_rallly() {
  info "Setting custom rallly parameters..." && \
    info "Generating RALLLY_SECRET_PASSWORD..." && \
    export RALLLY_SECRET_PASSWORD=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_') && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/rallly.yaml" && \
    info "Deploying rallly..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/rallly.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "RALLLY_DB_POSTGRES_PASSWORD: ${RALLLY_DB_POSTGRES_PASSWORD}"
  info "RALLLY_DB_PASSWORD: ${RALLLY_DB_PASSWORD}"
  info "RALLLY_SECRET_PASSWORD: ${RALLLY_SECRET_PASSWORD}"
  info "Please verify that 3 credentials are printed."
}

deploy_database
deploy_rallly
print_credentials

} # this ensures the entire script is downloaded #