#!/bin/bash

{ # this ensures the entire script is downloaded #

# import log library and set options
source "${BASH_SOURCE%/*}/shell-logger/shell-logger"
LOGGER_LEVEL=0
LOGGER_ERROR_TRACE=0
LOGGER_STDERR_LEVEL=4
LOGGER_COLOR=auto
LOGGER_TARGET=deploy.log

# function to check if command exist
script_has() {
  type "$1" > /dev/null 2>&1
}



} # this ensures the entire script is downloaded #