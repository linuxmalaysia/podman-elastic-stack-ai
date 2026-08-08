#!/bin/bash
# Common utility functions for Elastic Stack setup scripts.
# command_exists checks whether the specified command is available.

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
