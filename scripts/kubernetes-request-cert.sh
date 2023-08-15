#!/bin/bash

{ # this ensures the entire script is downloaded #

# load configuration
source "${SCRIPT_PATH}/conf/kubernetes.conf" || fatal_err "${SCRIPT_PATH}/conf/kubernetes.conf is missing"

get_user_input() {
  info "Getting inputs from user..."

  read -rp "Enter certificate common name (e.g. *.sub.example.com): " cert_cn
  if [[ -z "${cert_cn}" ]]; then
    fatal_err "Empty input"
  else
    export CERT_CN=${cert_cn}
  fi

  read -rp "Enter clusterissuer (microk8s kubectl get clusterissuer): " cluster_issuer
  if [[ -z "${cluster_issuer}" ]]; then
    fatal_err "Empty input"
  else
    export CERT_ISSUER=${cluster_issuer}
  fi

  info "Removing special characters from certificate common name..." && \
    export CERT_NAME=$(echo "$cert_cn" | tr -d -c '[:alnum:]')

  info "Generating certificate manifest..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/certificate.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/certificate.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/certificate-${CERT_NAME}.yaml" && \
    info "Deploying certificate manifest..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/certificate-${CERT_NAME}.yaml" || fatal_err "Failed to deploy certificate manifest"
}

} # this ensures the entire script is downloaded #