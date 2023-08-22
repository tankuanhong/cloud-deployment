#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/keycloak.conf" || fatal_err "${SCRIPT_PATH}/conf/keycloak.conf is missing"

wait_for_pods_ready "300" "default" "app=app-keycloak"

authorize_api() {
  info "Testing keycloak api access token..."

  if microk8s kubectl exec --stdin --tty deploy/dep-keycloak -- /bin/bash /opt/bitnami/keycloak/bin/kcadm.sh get realms --fields=realm --config=/bitnami/kcadm.config; then
    info "Tokens are still valid"
  else
    info "Requesting tokens..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-keycloak -- /bin/bash /opt/bitnami/keycloak/bin/kcadm.sh config credentials --server=http://localhost:8080 --realm=master --user=${KEYCLOAK_ADMIN_USER} --config=/bitnami/kcadm.config
  fi
}

authorize_api

} # this ensures the entire script is downloaded #