#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

deploy_dokuwiki() {
  info "Setting custom dokuwiki parameters..." && \
    info "Generating DOKUWIKI_ADMIN_PASSWORD..." && \
    export DOKUWIKI_ADMIN_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Populating env variables into manifest..." && \
    populate_yaml_env "${SCRIPT_PATH}/kubernetes/dokuwiki.yaml" && \
    info "Deploying dokuwiki..." && \
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/dokuwiki.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "DOKUWIKI_ADMIN_PASSWORD: ${DOKUWIKI_ADMIN_PASSWORD}"
  info "Please verify that 1 credential are printed."
}

# TODO: Add hardening of dokuwiki config if possible

deploy_dokuwiki
print_credentials

} # this ensures the entire script is downloaded #