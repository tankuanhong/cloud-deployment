#!/bin/bash

{ # this ensures the entire script is downloaded #

teleport_menu() {
  echo -ne "
[Teleport]

1) Deploy Teleport server 
2) Backup Teleport server
9) Back to main menu
0) Exit

Choose an option:  "
  read -r ans
  case $ans in
  1)
    echo "Deploying"
    exit 0
    ;;
  2)
    echo "Backing up"
    exit 0
    ;;
  9)
    clear
    main_menu
    ;;
  0)
    echo "Bye bye."
    exit 0
    ;;
  *)
    clear
    echo "Invalid option $ans"
    teleport_menu
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
  0)
    echo "Bye bye."
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