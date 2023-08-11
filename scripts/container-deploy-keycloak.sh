#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || { err "${SCRIPT_PATH}/conf/containers.conf is missing"; exit 1; }

check_kube_ready() {
  info "Checking Kubernetes cluster status..." && \
    if [ $(curl -k -s -o /dev/null -w "%{http_code}" https://localhost:6443/livez) -eq "200" ]; then
      info "Kubernetes cluster ok"
    else
      err "Kubernetes cluster not ok"
      err "Exiting..."
      exit 1
    fi
}

deploy_database() {
  info "Setting custom database parameters..." && \
    info "Generating POSTGRESQL_POSTGRES_PASSWORD..." && \
    export POSTGRESQL_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating POSTGRESQL_PASSWORD..." && \
    export POSTGRESQL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" && \
    info "Deploying database..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml"
}

deploy_keycloak() {
  info "Setting custom keycloak parameters..." && \
    info "Generating KEYCLOAK_ADMIN_PASSWORD..." && \
    export KEYCLOAK_ADMIN_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak.yaml" && \
    info "Deploying keycloak..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "POSTGRESQL_POSTGRES_PASSWORD: ${POSTGRESQL_POSTGRES_PASSWORD}"
  info "POSTGRESQL_PASSWORD: ${POSTGRESQL_PASSWORD}"
  info "KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}"
  info "Please verify that 3 credentials are printed."
}

check_kube_ready
deploy_database
deploy_keycloak
print_credentials

} # this ensures the entire script is downloaded #