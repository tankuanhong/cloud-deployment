#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

create_database_pvc() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/keycloak/keycloakdb-pvc.yaml" && \
    info "Creating database pvc..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak/keycloakdb-pvc.yaml"
}

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating KEYCLOAK_DB_POSTGRES_PASSWORD..." && \
    export KEYCLOAK_DB_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating KEYCLOAK_DB_PASSWORD..." && \
    export KEYCLOAK_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/keycloak/keycloakdb.yaml" && \
    info "Deploying database..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak/keycloakdb.yaml"
}

create_keycloak_pvc() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/keycloak/keycloak-pvc.yaml" && \
    info "Deploying keycloak pvc..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak/keycloak-pvc.yaml"
}

deploy_keycloak() {
  info "Setting custom keycloak parameters..." && \
    info "Generating KEYCLOAK_ADMIN_PASSWORD..." && \
    export KEYCLOAK_ADMIN_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/keycloak/keycloak.yaml" && \
    info "Deploying keycloak..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak/keycloak.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "KEYCLOAK_DB_POSTGRES_PASSWORD: ${KEYCLOAK_DB_POSTGRES_PASSWORD}"
  info "KEYCLOAK_DB_PASSWORD: ${KEYCLOAK_DB_PASSWORD}"
  info "KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}"
  info "Please verify that 3 credentials are printed."
}

create_database_pvc
deploy_database
create_keycloak_pvc
deploy_keycloak
print_credentials

} # this ensures the entire script is downloaded #