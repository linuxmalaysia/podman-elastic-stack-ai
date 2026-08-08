#!/bin/bash
# Common utility functions for Elastic Stack setup scripts.
# GNU GENERAL PUBLIC LICENSE Version 3

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
