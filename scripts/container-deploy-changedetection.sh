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

deploy_changedetection() {
  info "Setting custom changedetection.io parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/changedetection.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/changedetection.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/changedetection.yaml" && \
    info "Deploying changedetection.io..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/changedetection.yaml" && \
    info "Waiting for changedetection.io to be ready..." && \
    kubectl wait pods -l app=app-changedetection --for condition=Ready --timeout=120s
}

patch_ingress() {
  info "Patching changedetection.io ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" | envsubst '$CHANGEDETECTION_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml" && \
    kubectl patch ingress ing-changedetection --patch-file "${SCRIPT_PATH}/kubernetes/changedetection-ing-patch.yaml"
}

check_kube_ready
deploy_changedetection
patch_ingress

} # this ensures the entire script is downloaded #