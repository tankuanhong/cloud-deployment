#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || { err "${SCRIPT_PATH}/conf/containers.conf is missing" >&2; exit 1; }

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

deploy_memos() {
  info "Setting custom memos parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/memos.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/memos.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/memos.yaml" && \
    info "Deploying memos..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/memos.yaml" && \
    info "Waiting for memos to be ready..." && \
    kubectl wait pods -l app=app-memos --for condition=Ready --timeout=120s
}

check_kube_ready
deploy_memos

} # this ensures the entire script is downloaded #