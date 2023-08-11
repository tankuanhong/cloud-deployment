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

deploy_shlink_web() {
  info "Setting custom shlink web client parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" && \
    info "Deploying shlink web client..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/shlink-web.yaml" && \
    info "Waiting for shlink web client to be ready..." && \
    kubectl wait pods -l app=app-shlink-web --for condition=Ready --timeout=120s
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
    kubectl exec --stdin --tty deploy/dep-shlink -- shlink api-key:generate
}

check_kube_ready
deploy_database
deploy_shlink
deploy_shlink_web
print_credentials
generate_apikey

} # this ensures the entire script is downloaded #