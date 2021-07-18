#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  cp -v "$app_dir/bin/runcommand/onstart.sh" '/opt/retropie/configs/all/runcommand-onstart.sh'
  cp -v "$app_dir/bin/runcommand/onend.sh" '/opt/retropie/configs/all/runcommand-onend.sh'
  cp -v "$app_dir/bin/runcommand/tty.py" '/opt/retropie/configs/all/runcommand-tty.py'

  ini_merge "$config_dir/runcommand/runcommand.cfg" '/opt/retropie/configs/all/runcommand.cfg'
}

uninstall() {
  restore '/opt/retropie/configs/all/runcommand.cfg' delete_src=true
  rm -fv \
    '/opt/retropie/configs/all/runcommand-onstart.sh' \
    '/opt/retropie/configs/all/runcommand-onend.sh' \
    '/opt/retropie/configs/all/runcommand-tty.py'
}

"${@}"
