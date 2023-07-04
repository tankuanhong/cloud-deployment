#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/containers.conf" || exit

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

deploy_database() {

}

deploy_shlink() {

}

generate_apikey() {

}

deploy_shlink_web() {

}

patch_ingress() {

}

print_credentials() {

}

check_kube_ready
deploy_database
deploy_shlink
generate_apikey
deploy_shlink_web
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #