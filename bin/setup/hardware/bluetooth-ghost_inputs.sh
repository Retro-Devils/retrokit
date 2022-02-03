#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../../common.sh"

install() {
  backup_and_restore /usr/bin/btuart as_sudo=true
  sudo sed -i 's/bcm43xx 921600/bcm43xx 115200/g'
}

uninstall() {
  restore_file /usr/bin/btuart delete_src=true
}

"${@}"
