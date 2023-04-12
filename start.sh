#!/bin/bash

{ # this ensures the entire script is downloaded #

# constants
SCRIPT_PATH=$(dirname $(realpath -s $0))

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

1) Teleport
2) Gitea
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    clear
    teleport_menu
    ;;
  2)
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