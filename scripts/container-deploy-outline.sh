#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating OUTLINE_DB_POSTGRES_PASSWORD..." && \
    export OUTLINE_DB_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating OUTLINE_DB_PASSWORD..." && \
    export OUTLINE_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/outline-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/outline-db.yaml"
}

deploy_redis() {
  info "Setting custom redis parameters..." && \
    info "Generating OUTLINE_REDIS_PASSWORD..." && \
    export OUTLINE_REDIS_PASSWORD=$(openssl rand -hex 32 | tr -d -- '\n') && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/outline-redis.yaml" && \
    info "Deploying redis..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/outline-redis.yaml"
}

deploy_outline() {
  info "Setting custom outline parameters..." && \
    info "Generating OUTLINE_SECRET_KEY..." && \
    export OUTLINE_SECRET_KEY=$(openssl rand -hex 32 | tr -d -- '\n') && \
    info "Generating OUTLINE_UTILS_SECRET..." && \
    export OUTLINE_UTILS_SECRET=$(openssl rand -hex 32 | tr -d -- '\n') && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/outline.yaml" && \
    info "Deploying outline..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/outline.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "OUTLINE_DB_POSTGRES_PASSWORD: ${OUTLINE_DB_POSTGRES_PASSWORD}"
  info "OUTLINE_DB_PASSWORD: ${OUTLINE_DB_PASSWORD}"
  info "OUTLINE_REDIS_PASSWORD: ${OUTLINE_REDIS_PASSWORD}"
  info "OUTLINE_SECRET_KEY: ${OUTLINE_SECRET_KEY}"
  info "OUTLINE_UTILS_SECRET: ${OUTLINE_UTILS_SECRET}"
  info "Please verify that 5 credentials are printed."
}

deploy_database
deploy_redis
deploy_outline
print_credentials

} # this ensures the entire script is downloaded #