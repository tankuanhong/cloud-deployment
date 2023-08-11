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

fatal_err() {
  local exit_code=${1:-1}
  local message="$2"
  
  err "$message"
  exit "$exit_code"
}

# function to check linux distribution
check_linux_distribution() {
  local supported_os=("$@")
  
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    local current_id_and_version="$ID$VERSION_ID"
    
    if ! [[ "${supported_os[*]}" =~ "$current_id_and_version" ]]; then
      fatal_err "Exiting as distro is not one of the supported options: ${supported_os[*]}"
    fi
  else
    fatal_err "Unable to determine the Linux distribution"
  fi
}

} # this ensures the entire script is downloaded #