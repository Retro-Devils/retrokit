#!/bin/bash

set -ex

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  # PIP
  sudo apt install -y python3-pip

  # Ini editor
  sudo pip3 install crudini

  # Env editor
  download 'https://raw.githubusercontent.com/bashup/dotenv/master/dotenv' "$tmp_dir/dotenv"

  # JSON reader
  sudo apt install -y jq
}

uninstall() {
  sudo pip3 uninstall crudini
  rm -f "$tmp_dir/dotenv"
  sudo apt remove -y jq
}

"${@}"
