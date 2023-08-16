#!/bin/bash

{ # this ensures the entire script is downloaded #

# load configuration
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

enable_cert_manager() {
  info "Enabling cert-manager addon..." && \
    microk8s enable cert-manager || fatal_err "Failed to enable cert-manager addon"
}

get_cloudflare_token() {
  info "Getting cloudflare api token from user..."
  read -rp "Enter cloudflare api token: " api_token
  if [[ -z "${api_token}" ]]; then
    fatal_err "Empty input"
  else
    export CLOUDFLARE_TOKEN=${api_token}
  fi

  info "Generating CLOUDFLARE_TOKEN_NAME_SUFFIX..." && \
    export CLOUDFLARE_TOKEN_NAME_SUFFIX=$(tr -dc a-z0-9 </dev/urandom | head -c 5) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/cloudflare-api-token.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/cloudflare-api-token.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/cloudflare-api-token-${CLOUDFLARE_TOKEN_NAME_SUFFIX}.yaml" && \
    info "Deploying cloudflare api token..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/cloudflare-api-token-${CLOUDFLARE_TOKEN_NAME_SUFFIX}.yaml" || fatal_err "Failed to deploy cloudflare api token"
}

create_clusterissuer() {
  info "Creating cloudflare clusterissuer..." && \
    info "Generating LE_NAME_SUFFIX..." && \
    export LE_NAME_SUFFIX=$(tr -dc a-z0-9 </dev/urandom | head -c 5) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/cloudflare-clusterissuer.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/cloudflare-clusterissuer.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/cloudflare-clusterissuer-${LE_NAME_SUFFIX}.yaml" && \
    info "Deploying cloudflare clusterissuer..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/cloudflare-clusterissuer-${LE_NAME_SUFFIX}.yaml" || fatal_err "Failed to deploy cloudflare clusterissuer"
}

enable_cert_manager
get_cloudflare_token
create_clusterissuer

} # this ensures the entire script is downloaded #