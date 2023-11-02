#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

wait_for_node_ready "300"

deploy_ingress() {
  info "Deploying longhorn ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/longhorn-ing.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/longhorn-ing.yaml" | envsubst '$LONGHORN_LABEL,$LONGHORN_HOSTNAME,$LONGHORN_TLS_SECRET,$LONGHORN_OAUTH2_PROXY,$LONGHORN_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/longhorn-ing.yaml" && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/longhorn-ing.yaml"
}

deploy_ingress

} # this ensures the entire script is downloaded #