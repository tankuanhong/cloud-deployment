#!/bin/bash

{ # this ensures the entire script is downloaded #

# import
source "${SCRIPT_PATH}/shell-logger/shell-logger" || source "shell-logger" || { echo "shell-logger is missing"; exit 1; }
source "${SCRIPT_PATH}/conf/common.conf" || source "common.conf" || { echo "common.conf is missing"; exit 1; }

# function to check if command exist
command_exist() {
  type "$1" > /dev/null 2>&1
}

# function to check if service is active
service_active() {
  systemctl is-active --quiet $1
}

fatal_err() {
  local message="$1"
  local exit_code=${2:-1}
  
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

wait_for_ssh_ready() {
  local timeout="$1"
  local host="$2"
  local start_time=$(date +%s)
  
  until ssh -o StrictHostKeyChecking=accept-new -q $2 exit; do
    info "Waiting for ssh to $2 to be ready ($elapsed_time/$timeout)..."
    sleep 10
    
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    
    if [ "$elapsed_time" -ge "$timeout" ]; then
      fatal_err "Timeout waiting for ssh to $2 to be ready"
    fi
  done
}

wait_for_node_ready() {
  local timeout="$1"
  local start_time=$(date +%s)
  
  until microk8s kubectl get nodes | grep -w Ready; do
    info "Waiting for node to be ready ($elapsed_time/$timeout)..."
    sleep 10
    
    local current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    
    if [ "$elapsed_time" -ge "$timeout" ]; then
      fatal_err "Timeout waiting for node to be ready"
    fi
  done
}

wait_for_pods_ready() {
  local timeout="$1"
  local namespace="$2"
  local label="$3"
  
  local label_arg
  if [ -n "$label" ]; then
    label_arg="--selector=$label"
  else
    label_arg="--all"
  fi
  
  microk8s kubectl wait pods -n "$namespace" $label_arg --for condition=Ready --timeout=${timeout}s
}

} # this ensures the entire script is downloaded #