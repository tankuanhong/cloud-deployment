#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || exit
source "${SCRIPT_PATH}/conf/common.conf" || exit
source "${SCRIPT_PATH}/conf/kubernetes.conf" || exit
source "${SCRIPT_PATH}/conf/containers.conf" || exit

comment() {
  sed -i "$1"' s/^/#/' "$2"
}

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

check_pvc_exist() {
  info "Checking that required volumes exist..." && \
    if [ "$(kubectl get pvc pvc-keycloak-db >/dev/null 2>/dev/null; echo $?)" != '0' ] || [ "$(kubectl get pvc pvc-keycloak >/dev/null 2>/dev/null; echo $?)" != '0' ]; then
      err "Required persistent volume claims do not exist"
      err "Check that pvc-keycloak-db and pvc-keycloak are present"
      err "Exiting..."
      exit 1
    else
      info "Required volumes are present"
    fi
}

restore_database() {
  info "Setting custom database parameters..." && \
    info "Generating POSTGRESQL_POSTGRES_PASSWORD..." && \
    export POSTGRESQL_POSTGRES_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating POSTGRESQL_PASSWORD..." && \
    export POSTGRESQL_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" && \
    info "Disable creation of new persistent volume..." && \
    comment '/#PVC_START/,/#PVC_END/' "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml" && \
    info "Restoring database..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak-db.yaml"
}

restore_keycloak() {
  info "Setting custom keycloak parameters..." && \
    info "Generating KEYCLOAK_ADMIN_PASSWORD..." && \
    export KEYCLOAK_ADMIN_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/keycloak.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/keycloak.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/keycloak.yaml" && \
    info "Disable creation of new persistent volume..." && \
    comment '/#PVC_START/,/#PVC_END/' "${SCRIPT_PATH}/kubernetes/keycloak.yaml" && \
    info "Restoring keycloak..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/keycloak.yaml"
}

check_kube_ready
check_pvc_exist
restore_database
restore_keycloak

} # this ensures the entire script is downloaded #