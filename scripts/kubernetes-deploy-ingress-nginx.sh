#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || { err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"; exit 1; }

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

install_custom_headers() {
  info "Installing custom nginx header configmap..." && \
    kubectl create namespace ingress-nginx && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/ingress-nginx-custom-headers.yaml"
}

install_ingress_ctl() {
  info "Setting custom ingress nginx parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/ingress-nginx.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/ingress-nginx.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/ingress-nginx.yaml" && \
    info "Installing ingress nginx controller..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/ingress-nginx.yaml" && \
    info "Waiting for ingress nginx pods to be ready..." && \
    kubectl wait jobs -n ingress-nginx --all --for condition=Complete --timeout=120s
    kubectl wait pods -n ingress-nginx -l app.kubernetes.io/component=controller --for condition=Ready --timeout=120s
}

check_kube_ready
install_custom_headers
install_ingress_ctl

} # this ensures the entire script is downloaded #