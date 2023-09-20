#!/bin/bash

{ # this ensures the entire script is downloaded #

# Constants
SCRIPT_PATH=$(dirname "$(realpath -s "$0")")

# Import
source "${SCRIPT_PATH}/scripts/common-functions.sh" || source "common-functions.sh" || { echo "common-functions.sh is missing"; exit 1; }

# Check for supported os
check_linux_distribution "${SUPPORTED_OS[@]}"

# Function to display a menu
display_menu() {
  local title=$1
  shift
  local options=("$@")

  echo -e "
[$title]
"
  for i in "${!options[@]}"; do
    echo "$((i + 1))) ${options[i]}"
  done
  echo -e "
b) Back to Main Menu
x) Exit

Choose an option: "

  read -r ans
  case $ans in
    [1-9]|[1-9][0-9])
      if [[ $ans -le ${#options[@]} ]]; then
        clear
        local selected_option=$((ans - 1))
        if [[ ${options[selected_option]} == *.sh ]]; then
          source "${options[selected_option]}" || exit
        else
          "${options[selected_option]}" || exit
        fi
      else
        clear
        echo "Invalid option $ans"
        display_menu "$title" "${options[@]}"
      fi
      ;;
    b)
      clear
      main_menu
      ;;
    x)
      echo "Goodbye."
      exit 0
      ;;
    *)
      clear
      echo "Invalid option $ans"
      display_menu "$title" "${options[@]}"
      ;;
  esac
}

# Function to display the main menu
main_menu() {
  local main_menu=(
    "Main Menu"
    "teleport_menu"
    "gitea_menu"
    "syncthing_menu"
    "kubernetes_menu"
    "containers_menu"
    "keycloak_menu"
  )

  clear
  display_menu "${main_menu[@]}"
}

# Teleport submenu
teleport_menu() {
  local teleport=(
    "Teleport"
    "${SCRIPT_PATH}/scripts/teleport-deploy-proxy.sh"
    "${SCRIPT_PATH}/scripts/teleport-create-admin.sh"
    "${SCRIPT_PATH}/scripts/teleport-backup-proxy.sh"
    "${SCRIPT_PATH}/scripts/teleport-restore-proxy.sh"
  )
  display_menu "${teleport[@]}"
}

# Gitea submenu
gitea_menu() {
  local gitea=(
    "Gitea"
    "${SCRIPT_PATH}/scripts/gitea-deploy.sh"
    "echo 'Backing up Gitea'"
    "echo 'Restoring Gitea'"
  )
  display_menu "${gitea[@]}"
}

# Syncthing submenu
syncthing_menu() {
  local syncthing=(
    "Syncthing"
    "${SCRIPT_PATH}/scripts/syncthing-deploy-relay.sh"
  )
  display_menu "${syncthing[@]}"
}

# Kubernetes submenu
kubernetes_menu() {
  local kubernetes=(
    "Kubernetes"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-cluster.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-cert-issuer.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-request-cert.sh"
  )
  display_menu "${kubernetes[@]}"
}

# Containers submenu
containers_menu() {
  local containers=(
    "Containers"
    "${SCRIPT_PATH}/scripts/container-deploy-keycloak.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-oauth2-proxy.sh"

    "${SCRIPT_PATH}/scripts/container-deploy-changedetection.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-dokuwiki.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-fider.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-firefly3.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-gatus.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-grocy.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-healthchecks.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-memos.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-shlink.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-syncthing-discovery.sh"

    # TODO: Test rallly deployment (no arm64 images available)
    "${SCRIPT_PATH}/scripts/container-deploy-rallly.sh"

    # TODO: Add answer https://github.com/answerdev/answer
    # TODO: Add asciiflow https://github.com/lewish/asciiflow
    # TODO: Add babybuddy https://github.com/babybuddy/babybuddy
    # TODO: Add biodrop https://github.com/EddieHubCommunity/BioDrop
    # TODO: Add claper https://github.com/ClaperCo/Claper
    # TODO: Add dashy https://github.com/lissy93/dashy
    # TODO: Add drone ci https://github.com/harness/drone
    # TODO: Add fileshelter https://github.com/epoupon/fileshelter
    # TODO: Add formbricks https://github.com/formbricks/formbricks
    # TODO: Add grafana https://github.com/grafana/grafana
    # TODO: Add grafana loki https://github.com/grafana/loki
    # TODO: Add guacamole https://guacamole.apache.org/
    # TODO: Add homechart https://github.com/candiddev/homechart
    # TODO: Add ihatemoney https://github.com/spiral-project/ihatemoney
    # TODO: Add mailcatcher (for testing) https://hub.docker.com/r/dockage/mailcatcher
    # TODO: Add mealie https://github.com/mealie-recipes/mealie
    # TODO: Add miniflux https://github.com/miniflux/v2
    # TODO: Add nomie https://github.com/open-nomie/nomie6-oss
    # TODO: Add pairdrop https://github.com/schlagmichdoch/pairdrop
    # TODO: Add peertube https://github.com/Chocobozzz/PeerTube
    # TODO: Add prometheus https://github.com/prometheus/prometheus
    # TODO: Add qr-code-styling https://github.com/kozakdenys/qr-code-styling
    # TODO: Add seatsurfing https://github.com/seatsurfing/backend
    # TODO: Add speedtest https://github.com/openspeedtest/Speed-Test
    # TODO: Add talkyard https://github.com/debiki/talkyard
    # TODO: Add transfer.sh https://github.com/dutchcoders/transfer.sh
    # TODO: Add vaultwarden https://github.com/dani-garcia/vaultwarden
    # TODO: Add webhook.site https://github.com/webhooksite/webhook.site
    # TODO: Add whitebophir https://github.com/lovasoa/whitebophir
    
    # TODO: Convert gitea deployment from standalone to container

    # TODO: Refactor and test keycloak restore
    "${SCRIPT_PATH}/scripts/container-restore-keycloak.sh"
  )
  display_menu "${containers[@]}"
}

# Keycloak submenu
keycloak_menu() {
  local keycloak=(
    "Keycloak"
    "${SCRIPT_PATH}/scripts/keycloak-authorize-api.sh"
    "${SCRIPT_PATH}/scripts/keycloak-create-realm.sh"
    "${SCRIPT_PATH}/scripts/keycloak-create-client-oauth2-proxy.sh"
    "${SCRIPT_PATH}/scripts/keycloak-create-client-meetable.sh"

    # TODO: Add create client script for dokuwiki app
    # TODO: Add create client script for memos app
  )
  display_menu "${keycloak[@]}"
}

# Run the main menu function
main_menu

} # this ensures the entire script is downloaded #