#!/bin/bash

set -ex

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

setup() {
  sudo systemctl enable ssh
  sudo systemctl start ssh
}

setup
