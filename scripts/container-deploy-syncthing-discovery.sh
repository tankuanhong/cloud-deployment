#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/syncthing.conf" || fatal_err "${SCRIPT_PATH}/conf/syncthing.conf is missing"

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

deploy_discovery() {
  info "Setting custom syncthing discovery parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml" && \
    info "Deploying syncthing discovery..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/syncthing-discovery.yaml"
}

check_kube_ready
deploy_discovery

} # this ensures the entire script is downloaded #