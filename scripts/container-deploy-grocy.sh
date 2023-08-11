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

disable_clear_env() {
  info "Disabling clear_env to allow environment variables..." && \
    kubectl exec --stdin --tty deploy/dep-grocy -- bash -c "grep -qxF 'clear_env = no' /config/php/www2.conf || echo 'clear_env = no' >> /config/php/www2.conf" && \
    kubectl delete pod -l app=app-grocy
}

patch_ingress() {
  info "Patching grocy ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" | envsubst '$GROCY_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" && \
    kubectl patch ingress ing-grocy --patch-file "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml"
}

check_kube_ready
deploy_grocy
disable_clear_env
patch_ingress

} # this ensures the entire script is downloaded #