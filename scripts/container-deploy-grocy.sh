#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_grocy() {
  info "Setting custom grocy parameters..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/grocy.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/grocy.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/grocy.yaml" && \
    info "Deploying grocy..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/grocy.yaml" && \
    info "Waiting for grocy to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${GROCY_LABEL}"
}

disable_clear_env() {
  info "Disabling clear_env to allow environment variables..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-${GROCY_LABEL} -- bash -c "grep -qxF 'clear_env = no' /config/php/www2.conf || echo 'clear_env = no' >> /config/php/www2.conf" && \
    microk8s kubectl delete pod -l app=app-${GROCY_LABEL}
}

patch_ingress() {
  info "Patching grocy ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" | envsubst '$GROCY_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-grocy --patch-file "${SCRIPT_PATH}/kubernetes/grocy-ing-patch.yaml"
}

deploy_grocy
disable_clear_env
patch_ingress

} # this ensures the entire script is downloaded #