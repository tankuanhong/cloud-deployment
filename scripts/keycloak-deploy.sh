#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit
source "${SCRIPT_PATH}/conf/containers.conf" || exit

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
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" && \
    info "Deploying database..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml"
}

deploy_keycloak() {
  info "Setting custom keycloak parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak.yaml" && \
    info "Deploying keycloak..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak.yaml"
}

check_kube_ready
deploy_database
deploy_keycloak

} # this ensures the entire script is downloaded #