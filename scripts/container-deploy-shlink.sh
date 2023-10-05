#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating SHLINK_DB_ROOT_PASSWORD..." && \
    export SHLINK_DB_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating SHLINK_DB_PASSWORD..." && \
    export SHLINK_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/shlink-db.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink-db.yaml"
}

deploy_shlink() {
  info "Setting custom shlink parameters..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/shlink.yaml" && \
    info "Deploying shlink..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink.yaml" && \
    info "Waiting for shlink to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${SHLINK_LABEL}"
}

deploy_shlink_web() {
  info "Setting custom shlink web client parameters..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" && \
    info "Deploying shlink web client..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" && \
    info "Waiting for shlink web client to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${SHLINK_WEB_LABEL}"
}

print_credentials() {
  info "Please save the following credentials."
  info "SHLINK_DB_ROOT_PASSWORD: ${SHLINK_DB_ROOT_PASSWORD}"
  info "SHLINK_DB_PASSWORD: ${SHLINK_DB_PASSWORD}"
  info "Please verify that 2 credentials are printed."
}

generate_apikey() {
  info "Sleep 1 minute for application to initialize..." && \
    sleep 60 && \
    info "Wake after 1 minute" && \
    info "Generating first api key..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-${SHLINK_LABEL} -- shlink api-key:generate
}

deploy_database
deploy_shlink
deploy_shlink_web
print_credentials
generate_apikey

} # this ensures the entire script is downloaded #