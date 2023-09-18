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

create_client() {
  info "Creating oauth2-proxy client in keycloak realm ${KEYCLOAK_REALM}..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-keycloak -- /bin/bash /opt/bitnami/keycloak/bin/kcadm.sh create clients -r ${KEYCLOAK_REALM} --config=/bitnami/kcadm.config -f - << EOF
{
  "clientId" : "${KEYCLOAK_CLIENT_OAUTH2PROXY}",
  "name" : "",
  "description" : "",
  "rootUrl" : "",
  "adminUrl" : "",
  "baseUrl" : "",
  "surrogateAuthRequired" : false,
  "enabled" : true,
  "alwaysDisplayInConsole" : false,
  "clientAuthenticatorType" : "client-secret",
  "redirectUris" : [ "/*" ],
  "webOrigins" : [ "/*" ],
  "redirectUris" : [ ],
  "webOrigins" : [ ],
  "notBefore" : 0,
  "bearerOnly" : false,
  "consentRequired" : false,
  "standardFlowEnabled" : true,
  "implicitFlowEnabled" : false,
  "directAccessGrantsEnabled" : true,
  "serviceAccountsEnabled" : false,
  "publicClient" : false,
  "frontchannelLogout" : true,
  "protocol" : "openid-connect",
  "attributes" : {
    "oidc.ciba.grant.enabled" : "false",
    "oauth2.device.authorization.grant.enabled" : "false",
    "backchannel.logout.session.required" : "true",
    "backchannel.logout.revoke.offline.tokens" : "false"
  },
  "authenticationFlowBindingOverrides" : { },
  "fullScopeAllowed" : true,
  "nodeReRegistrationTimeout" : -1,
  "protocolMappers" : [ {
    "name" : "audience",
    "protocol" : "openid-connect",
    "protocolMapper" : "oidc-audience-mapper",
    "consentRequired" : false,
    "config" : {
      "included.client.audience" : "${KEYCLOAK_CLIENT_OAUTH2PROXY}",
      "id.token.claim" : "true",
      "access.token.claim" : "true",
      "included.custom.audience" : "${KEYCLOAK_CLIENT_OAUTH2PROXY}"
    }
  } ],
  "defaultClientScopes" : [ "web-origins", "acr", "profile", "roles", "email" ],
  "optionalClientScopes" : [ "address", "phone", "offline_access", "microprofile-jwt" ],
  "access" : {
    "view" : true,
    "configure" : true,
    "manage" : true
  }
}
EOF
}

test_token
create_client

} # this ensures the entire script is downloaded #