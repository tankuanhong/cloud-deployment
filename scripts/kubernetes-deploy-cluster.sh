#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit

deploy_master() {
  info "Deploying master node" && \
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-master.sh" || exit
}

main() {
  deploy_master
}

main

} # this ensures the entire script is downloaded #