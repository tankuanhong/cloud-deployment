#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/conf/containers.conf" || fatal_err "${SCRIPT_PATH}/conf/containers.conf is missing"

wait_for_node_ready "300"

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
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/healthchecks-db.yaml" && \
    info "Waiting for database to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${HEALTHCHECKS_DB_LABEL}"
  
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
    microk8s kubectl apply -f "${SCRIPT_PATH}/kubernetes/healthchecks.yaml" && \
    info "Waiting for healthchecks to be ready..." && \
    wait_for_pods_ready "300" "default" "app=app-${HEALTHCHECKS_LABEL}"

  info "Sleep 1 minute for app to initialize..." && \
    sleep 60 && \
    info "Wake after 1 minute"
}

create_superuser() {
  if [ ! -n "$HEALTHCHECKS_USER_HEADER" ]; then
    info "Creating superuser account for healthchecks..." && \
    info "Generating HEALTHCHECKS_SUPERUSER_PASS..." && \
    export HEALTHCHECKS_SUPERUSER_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c $(shuf -i 39-63 -n 1)) && \
    microk8s kubectl exec --stdin --tty deploy/dep-${HEALTHCHECKS_LABEL} -- /opt/healthchecks/manage.py shell -c "from django.contrib.auth.models import User; User.objects.create_superuser('${HEALTHCHECKS_SUPERUSER}', '${HEALTHCHECKS_SUPERUSER_EMAIL}', '${HEALTHCHECKS_SUPERUSER_PASS}')"
  else
    info "Authentication using keycloak, skipping superuser account creation"
  fi
}

set_telegram_webhook() {
  if [ -n "$HEALTHCHECKS_TELEGRAM_BOT" ] && [ -n "$HEALTHCHECKS_TELEGRAM_TOKEN" ]; then
    info "Invoking Telegram's setWebhook API call..." && \
    microk8s kubectl exec --stdin --tty deploy/dep-${HEALTHCHECKS_LABEL} -- /opt/healthchecks/manage.py settelegramwebhook
  fi
}

patch_ingress() {
  info "Patching healthchecks ingress..." && \
    tmpfile=$(mktemp) && \
    cp --attributes-only --preserve "${SCRIPT_PATH}/kubernetes/healthchecks-ing-patch.yaml" $tmpfile && \
    cat "${SCRIPT_PATH}/kubernetes/healthchecks-ing-patch.yaml" | envsubst '$HEALTHCHECKS_LABEL,$HEALTHCHECKS_AUTH_QUERY' > $tmpfile && \
    mv $tmpfile "${SCRIPT_PATH}/kubernetes/healthchecks-ing-patch.yaml" && \
    microk8s kubectl patch ingress ing-${HEALTHCHECKS_LABEL} --patch-file "${SCRIPT_PATH}/kubernetes/healthchecks-ing-patch.yaml"
}

print_credentials() {
  info "Please save the following credentials."
  info "HEALTHCHECKS_DB_ROOT_PASSWORD: ${HEALTHCHECKS_DB_ROOT_PASSWORD}"
  info "HEALTHCHECKS_DB_PASSWORD: ${HEALTHCHECKS_DB_PASSWORD}"
  info "HEALTHCHECKS_SUPERUSER_PASS: ${HEALTHCHECKS_SUPERUSER_PASS}"
  info "Please verify that 3 credentials are printed."
}

deploy_database
deploy_healthchecks
create_superuser
set_telegram_webhook
patch_ingress
print_credentials

} # this ensures the entire script is downloaded #