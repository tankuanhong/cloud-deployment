#!/bin/bash

{ # this ensures the entire script is downloaded #

# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

} # this ensures the entire script is downloaded #