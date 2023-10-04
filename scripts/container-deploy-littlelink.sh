#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

set_caddy_env() {
  info "Setting caddy deployment env vars..." && \
    export CADDY_LABEL=${LITTLELINK_LABEL} && \
    export CADDY_PVC_SIZE=${LITTLELINK_PVC_SIZE} && \
    export CADDY_IMAGE=${LITTLELINK_IMAGE} && \
    export CADDY_HOSTNAME=${LITTLELINK_HOSTNAME} && \
    export CADDY_TLS_SECRET=${LITTLELINK_TLS_SECRET}
}

deploy_caddyfile() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/${CADDY_LABEL}-cfg.yaml" && \
    info "Deploying caddyfile..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/${CADDY_LABEL}-cfg.yaml"
}

deploy_caddy() {
  info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/caddy.yaml" && \
    info "Deploying caddy..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/caddy.yaml" && \
    info "Waiting for caddy to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${CADDY_LABEL}"
}

deploy_littlelink() {
  info "Installing git into container..." && \
    export LITTLELINK_CLONE_URL="https://${LITTLELINK_REPO_USERNAME}:${LITTLELINK_REPO_PASSWORD}@${LITTLELINK_REPO_URL#https://}"
    microk8s kubectl exec --stdin --tty deploy/dep-${CADDY_LABEL} -- apk update && \
    microk8s kubectl exec --stdin --tty deploy/dep-${CADDY_LABEL} -- apk add git && \
    microk8s kubectl exec --stdin --tty deploy/dep-${CADDY_LABEL} -- git clone ${LITTLELINK_CLONE_URL} /data/caddy
}

set_caddy_env
deploy_caddyfile
deploy_caddy
deploy_littlelink

} # this ensures the entire script is downloaded #