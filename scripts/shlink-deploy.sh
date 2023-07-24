#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
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
    info "Generating SHLINK_DB_ROOT_PASSWORD..." && \
    export SHLINK_DB_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating SHLINK_DB_PASSWORD..." && \
    export SHLINK_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/shlink-db.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/shlink-db.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/shlink-db.yaml" && \
    info "Deploying database..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink-db.yaml"
}

deploy_shlink() {
  info "Setting custom shlink parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/shlink.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/shlink.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/shlink.yaml" && \
    info "Deploying shlink..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink.yaml" && \
    info "Waiting for shlink to be ready..." && \
    kubectl wait pods -l app=app-shlink --for condition=Ready --timeout=120s
}

generate_apikey() {

}

deploy_shlink_web() {

}

patch_ingress() {

}

print_credentials() {

}

check_kube_ready
deploy_database
deploy_shlink
generate_apikey
deploy_shlink_web
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #