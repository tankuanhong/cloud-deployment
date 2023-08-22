#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/keycloak.conf" || fatal_err "${SCRIPT_PATH}/conf/keycloak.conf is missing"

wait_for_pods_ready "300" "default" "app=app-keycloak"

test_token() {
  info "Testing keycloak api access token..."

  if microk8s kubectl exec --stdin --tty deploy/dep-keycloak -- /bin/bash /opt/bitnami/keycloak/bin/kcadm.sh get realms --fields=realm --config=/bitnami/kcadm.config; then
    info "Tokens are still valid"
  else
    fatal_err "Tokens expired, run keycloak-authorize-api.sh to renew tokens"
  fi
}

create_realm() {
  info "Creating keycloak realm..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-keycloak -- /bin/bash /opt/bitnami/keycloak/bin/kcadm.sh create realms -s realm=${KEYCLOAK_REALM} -s enabled=true --config=/bitnami/kcadm.config
}

test_token
create_realm

} # this ensures the entire script is downloaded #