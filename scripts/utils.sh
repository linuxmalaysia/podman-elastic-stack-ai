#!/usr/bin/env bash
# ==============================================================================
# Script Name : utils.sh
# Purpose     : Common utility helper functions for setup and installation scripts
# Author      : Podman Elastic Stack AI Engineering Team
# License     : GNU General Public License v3.0
# Requirements: POSIX-compliant Bourne-again Shell (bash 4.0+)
# Usage       : source /path/to/scripts/utils.sh
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: command_exists
# Description: Checks if a given executable or shell builtin is available on PATH.
# Arguments  : $1 - Command name to check (e.g. "podman", "curl", "python3")
# Returns    : 0 if command exists and is executable, 1 otherwise
# ------------------------------------------------------------------------------
command_exists() {
  # Redirect both standard output and error to /dev/null for silent probe
  command -v "$1" >/dev/null 2>&1
}
