#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating FIDER_DB_POSTGRES_PASSWORD..." && \
    export FIDER_DB_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating FIDER_DB_PASSWORD..." && \
    export FIDER_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/fider-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/fider-db.yaml"
}

deploy_fider() {
  info "Setting custom fider parameters..." && \
    info "Generating FIDER_JWT_SECRET..." && \
    export FIDER_JWT_SECRET=$(openssl rand -base64 64 | tr -d -- '\n') && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/fider.yaml" && \
    info "Deploying fider..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/fider.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "FIDER_DB_POSTGRES_PASSWORD: ${FIDER_DB_POSTGRES_PASSWORD}"
  info "FIDER_DB_PASSWORD: ${FIDER_DB_PASSWORD}"
  info "FIDER_JWT_SECRET: ${FIDER_JWT_SECRET}"
  info "Please verify that 3 credentials are printed."
}

deploy_database
deploy_fider
print_credentials

} # this ensures the entire script is downloaded #