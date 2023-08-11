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

get_domain_name() {
  info "Obtaining domain name from user..."
  regex="(?=^.{4,253}$)(^(?:[a-zA-Z0-9](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z0-9])?\.)+([a-zA-Z]{2,}|xn--[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])$)"
  
  read -rp "Enter domain name to be proxied: " proxy_domain
  if [[ -z "${proxy_domain}" ]]; then
    err "Empty input"
    exit 1
  elif [[ "$(echo "${proxy_domain}" | grep -Pq "$regex"; echo $?)" = '0' ]]; then
    info "Domain validated"
    export OAUTH2_PROXY_DOMAIN=${proxy_domain}
    export OAUTH2_PROXY_SUFFIX=${proxy_domain//./}
  else
    err "You have entered an invalid domain"
    exit 1
  fi
}

install_oauth2_proxy() {
  info "Checking for existing deployment..." && \
    if [ kubectl get deployment dep-oauth2-${OAUTH2_PROXY_SUFFIX} ]; then
      err "dep-oauth2-${OAUTH2_PROXY_SUFFIX} already exist"
      exit 1
    fi
  
  info "Setting custom oauth2-proxy parameters..." && \
    info "Generating OAUTH2_COOKIE_SECRET..." && \
    export OAUTH2_COOKIE_SECRET=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_') && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/oauth2-proxy.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/oauth2-proxy.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/oauth2-${OAUTH2_PROXY_SUFFIX}.yaml" && \
    info "Installing oauth2-proxy for ${OAUTH2_PROXY_DOMAIN}..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/oauth2-${OAUTH2_PROXY_SUFFIX}.yaml" && \
    info "Waiting for oauth2-proxy pods to be ready..." && \
    kubectl wait pods -l app=app-oauth2-${OAUTH2_PROXY_SUFFIX} --for condition=Ready --timeout=120s
}

check_kube_ready
get_domain_name
install_oauth2_proxy

} # this ensures the entire script is downloaded #