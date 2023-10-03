#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating GHOST_DB_ROOT_PASSWORD..." && \
    export GHOST_DB_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating GHOST_DB_PASSWORD..." && \
    export GHOST_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/ghost-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/ghost-db.yaml" && \
    info "Waiting for database to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${GHOST_DB_LABEL}"
}

deploy_ghost() {
  info "Waiting 1 minute for database to initialize" && \
    sleep 60 && \
    info "Setting custom ghost parameters..." && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/ghost.yaml" && \
    info "Deploying ghost..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/ghost.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "GHOST_DB_ROOT_PASSWORD: ${GHOST_DB_ROOT_PASSWORD}"
  info "GHOST_DB_PASSWORD: ${GHOST_DB_PASSWORD}"
  info "Please verify that 2 credentials are printed."
}

deploy_database
deploy_ghost
print_credentials

} # this ensures the entire script is downloaded #