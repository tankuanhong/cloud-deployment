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
    "dokuwiki_menu"
    "gitea_menu"
    "syncthing_menu"
    "kubernetes_menu"
    "containers_menu"
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

# Dokuwiki submenu
dokuwiki_menu() {
  local dokuwiki=(
    "Dokuwiki"
    "${SCRIPT_PATH}/scripts/dokuwiki-deploy.sh"
    "${SCRIPT_PATH}/scripts/dokuwiki-harden.sh"
    "echo 'Backing up Dokuwiki'"
    "echo 'Restoring Dokuwiki'"
  )
  display_menu "${dokuwiki[@]}"
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
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-nfs-backup.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-longhorn.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-ingress-nginx.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-oauth2-proxy.sh"
    "${SCRIPT_PATH}/scripts/kubernetes-deploy-single-node.sh"
  )
  display_menu "${kubernetes[@]}"
}

# Containers submenu
containers_menu() {
  local containers=(
    "Containers"
    "${SCRIPT_PATH}/scripts/container-deploy-keycloak.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-firefly3.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-healthchecks.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-changedetection.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-gatus.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-grocy.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-memos.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-shlink.sh"
    "${SCRIPT_PATH}/scripts/container-deploy-syncthing-discovery.sh"
    "${SCRIPT_PATH}/scripts/container-restore-keycloak.sh"
  )
  display_menu "${containers[@]}"
}

# Run the main menu function
main_menu

} # this ensures the entire script is downloaded #