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
  info "Setting custom database parameters..." && \
    info "Generating HEALTHCHECKS_DB_ROOT_PASSWORD..." && \
    export HEALTHCHECKS_DB_ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    info "Generating HEALTHCHECKS_DB_PASSWORD..." && \
    export HEALTHCHECKS_DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/healthchecks-db.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/healthchecks-db.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/healthchecks-db.yaml" && \
    info "Deploying database..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/healthchecks-db.yaml" && \
    info "Waiting for database to be ready..." && \
    kubectl wait pods -l app=app-healthchecks-db --for condition=Ready --timeout=120s
  
  info "Sleep 1 minute for database to initialize..." && \
    sleep 60 && \
    info "Wake after 1 minute"
}

deploy_healthchecks() {
  info "Setting custom healthchecks parameters..." && \
    info "Generating HEALTHCHECKS_SECRET_KEY..." && \
    export HEALTHCHECKS_SECRET_KEY=$(tr -dc 'A-Za-z0-9!@#$%^&*(-_=+)' </dev/urandom | head -c $(shuf -i 50-100 -n 1)) && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/healthchecks.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/healthchecks.yaml" | envsubst > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/healthchecks.yaml" && \
    info "Deploying healthchecks..." && \
    kubectl apply -f "${SCRIPT_PATH}/kubernetes/healthchecks.yaml" && \
    info "Waiting for healthchecks to be ready..." && \
    kubectl wait pods -l app=app-healthchecks --for condition=Ready --timeout=120s

  info "Sleep 1 minute for app to initialize..." && \
    sleep 60 && \
    info "Wake after 1 minute"
}

create_superuser() {
  info "Creating superuser account for healthchecks..." && \
    info "Generating HEALTHCHECKS_SUPERUSER_PASS..." && \
    export HEALTHCHECKS_SUPERUSER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    kubectl exec --stdin --tty deploy/dep-healthchecks -- /opt/healthchecks/manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('${HEALTHCHECKS_SUPERUSER}', '${HEALTHCHECKS_SUPERUSER_EMAIL}', '${HEALTHCHECKS_SUPERUSER_PASS}')"
}

patch_ingress() {
  info "Patching healthchecks ingress..." && \
    kubectl patch ingress ing-healthchecks --patch-file "${SCRIPT_PATH}/kubernetes/healthchecks-ing-headers.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "HEALTHCHECKS_DB_ROOT_PASSWORD: ${HEALTHCHECKS_DB_ROOT_PASSWORD}"
  info "HEALTHCHECKS_DB_PASSWORD: ${HEALTHCHECKS_DB_PASSWORD}"
  info "HEALTHCHECKS_SUPERUSER_PASS: ${HEALTHCHECKS_SUPERUSER_PASS}"
  info "Please verify that 3 credentials are printed."
}

check_kube_ready
deploy_database
deploy_healthchecks
create_superuser
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #