#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

wait_for_node_ready "300"

deploy_ingress() {
  info "Deploying kubernetes dashboard ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/kubedash-ing.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/kubedash-ing.yaml" | envsubst '$KUBEDASH_LABEL,$KUBEDASH_HOSTNAME,$KUBEDASH_TLS_SECRET,$KUBEDASH_OAUTH2_PROXY,$KUBEDASH_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/kubedash-ing.yaml" && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/kubedash-ing.yaml"
}

deploy_ingress

} # this ensures the entire script is downloaded #