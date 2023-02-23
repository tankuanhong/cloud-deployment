#!/bin/bash

{ # this ensures the entire script is downloaded #


# function to check if command exist
script_has() {
  type "$1" > /dev/null 2>&1
}

# function to print 
script_echo() {
  command printf %s\\n "$*" >>$logfile_name
}


} # this ensures the entire script is downloaded #