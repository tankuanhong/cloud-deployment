#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

get_domain_name() {
  info "Obtaining domain name from user..."
  regex="(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)"
  
  read -rp "Enter domain name (e.g. sub.example.com) to be proxied: " proxy_domain
  if [[ -z "${proxy_domain}" ]]; then
    fatal_err "Empty input"
  elif [[ "$(echo "${proxy_domain}" | grep -Pq "$regex"; echo $?)" = '0' ]]; then
    info "Domain validated"
    export OAUTH2_PROXY_DOMAIN=${proxy_domain}
    export OAUTH2_PROXY_SUFFIX=${proxy_domain//./}
  else
    fatal_err "Invalid domain. Input should follow this format: subdomain.domain.tld"
  fi
}

install_oauth2_proxy() {
  info "Checking for existing deployment..." && \
    if [ "$(microk8s kubectl get deployment dep-oauth2-${OAUTH2_PROXY_SUFFIX} >/dev/null 2>/dev/null; echo $?)" = '0' ]; then
      fatal_err "dep-oauth2-${OAUTH2_PROXY_SUFFIX} already exist"
    fi
  
  info "Setting custom oauth2-proxy parameters..." && \
    info "Generating OAUTH2_COOKIE_SECRET..." && \
    export OAUTH2_COOKIE_SECRET=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_') && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/oauth2-proxy.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/oauth2-proxy.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/oauth2-${OAUTH2_PROXY_SUFFIX}.yaml" && \
    info "Installing oauth2-proxy for ${OAUTH2_PROXY_DOMAIN}..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/oauth2-${OAUTH2_PROXY_SUFFIX}.yaml" || fatal_err "Failed to deploy oauth2-${OAUTH2_PROXY_SUFFIX} pods"

    info "Waiting for oauth2-${OAUTH2_PROXY_SUFFIX} pods to be ready..."
    wait_for_pods_ready "300" "default" "app=app-oauth2-${OAUTH2_PROXY_SUFFIX}"
}

get_domain_name
install_oauth2_proxy

} # this ensures the entire script is downloaded #