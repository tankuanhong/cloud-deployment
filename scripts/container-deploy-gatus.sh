#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

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

deploy_gatus() {
  info "Setting custom gatus parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/gatus.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/gatus.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/gatus.yaml" && \
    info "Deploying gatus..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/gatus.yaml" && \
    info "Waiting for gatus to be ready..." && \
    kubectl wait pods -l app=app-gatus --for condition=Ready --timeout=120s
}

check_kube_ready
deploy_gatus

} # this ensures the entire script is downloaded #