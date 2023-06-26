#!/bin/bash

{ # this ensures the entire script is downloaded #

# constants
SCRIPT_PATH=$(dirname $(realpath -s $0))

kubernetes_menu() {
  echo -ne "
[Kubernetes]

1) Deploy Kubernetes Cluster
2) Deploy NFS Backup Server
3) Deploy Longhorn Storage
4) Deploy Ingress NGINX Controller
5) Deploy oAuth2 Proxy
6) Deploy Kubernetes for testing (Single-Node)
9) Back to Main Menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-cluster.sh" || exit
    exit 0
    ;;
  2)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-nfs-backup.sh" || exit
    exit 0
    ;;
  3)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-longhorn.sh" || exit
    exit 0
    ;;
  4)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-ingress-nginx.sh" || exit
    exit 0
    ;;
  5)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-oauth2-proxy.sh" || exit
    exit 0
    ;;
  6)
    source "${SCRIPT_PATH}/scripts/kubernetes-deploy-single-node.sh" || exit
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    kubernetes_menu
    ;;
  esac
}

containers_menu() {
  echo -ne "
[Containers]

1) Deploy Keycloak to new PersistentVolume
2) Deploy Firefly to new PersistentVolume
3) Deploy Healthchecks to new PersistentVolume
4) Deploy changedetection.io to new PersistentVolume
5) Deploy Gatus to new PersistentVolume
6) Deploy Grocy to new PersistentVolume
7) Restore Keycloak from existing PersistentVolume
9) Back to Main Menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    source "${SCRIPT_PATH}/scripts/keycloak-deploy.sh" || exit
    exit 0
    ;;
  2)
    source "${SCRIPT_PATH}/scripts/firefly3-deploy.sh" || exit
    exit 0
    ;;
  3)
    source "${SCRIPT_PATH}/scripts/healthchecks-deploy.sh" || exit
    exit 0
    ;;
  4)
    source "${SCRIPT_PATH}/scripts/changedetection-deploy.sh" || exit
    exit 0
    ;;
  5)
    source "${SCRIPT_PATH}/scripts/gatus-deploy.sh" || exit
    exit 0
    ;;
  6)
    source "${SCRIPT_PATH}/scripts/grocy-deploy.sh" || exit
    exit 0
    ;;
  7)
    source "${SCRIPT_PATH}/scripts/keycloak-restore.sh" || exit
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    containers_menu
    ;;
  esac
}

teleport_menu() {
  echo -ne "
[Teleport]

1) Deploy Teleport Proxy
2) Create Teleport Admin User
3) Backup Teleport Proxy
4) Restore Teleport Proxy
9) Back to Main Menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    source "${SCRIPT_PATH}/scripts/teleport-deploy-proxy.sh" || exit
    exit 0
    ;;
  2)
    source "${SCRIPT_PATH}/scripts/teleport-create-admin.sh" || exit
    exit 0
    ;;
  3)
    source "${SCRIPT_PATH}/scripts/teleport-backup-proxy.sh" || exit
    exit 0
    ;;
  4)
    source "${SCRIPT_PATH}/scripts/teleport-restore-proxy.sh" || exit
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    teleport_menu
    ;;
  esac
}

dokuwiki_menu() {
  echo -ne "
[Dokuwiki]

1) Deploy Dokuwiki
2) Backup Dokuwiki
3) Restore Dokuwiki
9) Back to Main Menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    source "${SCRIPT_PATH}/scripts/dokuwiki-deploy.sh" || exit
    exit 0
    ;;
  2)
    echo "Backing up Dokuwiki"
    exit 0
    ;;
  3)
    echo "Restoring Dokuwiki"
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    dokuwiki_menu
    ;;
  esac
}

gitea_menu() {
  echo -ne "
[Gitea]

1) Deploy Gitea
2) Backup Gitea
3) Restore Gitea
9) Back to Main Menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    source "${SCRIPT_PATH}/scripts/gitea-deploy.sh" || exit
    exit 0
    ;;
  2)
    echo "Backing up Gitea"
    exit 0
    ;;
  3)
    echo "Restoring Gitea"
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    gitea_menu
    ;;
  esac
}

main_menu() {
  echo -ne "
[Main Menu]

1) Kubernetes
2) Containers
3) Teleport
4) Dokuwiki
5) Gitea
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    clear
    kubernetes_menu
    ;;
  2)
    clear
    containers_menu
    ;;
  3)
    clear
    teleport_menu
    ;;
  4)
    clear
    dokuwiki_menu
    ;;
  5)
    clear
    gitea_menu
    ;;
  0)
    echo "Good bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    main_menu
    ;;
  esac
}

clear
main_menu

} # this ensures the entire script is downloaded #