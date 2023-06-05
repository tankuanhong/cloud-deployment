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

deploy_grocy() {
  info "Setting custom grocy parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/grocy.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/grocy.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/grocy.yaml" && \
    info "Deploying grocy..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/grocy.yaml" && \
    info "Waiting for grocy to be ready..." && \
    kubectl wait pods -l app=app-grocy --for condition=Ready --timeout=120s
}

check_kube_ready
deploy_grocy

} # this ensures the entire script is downloaded #