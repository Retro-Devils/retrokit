#!/bin/bash

set -ex

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  file_ln "$app_dir/bin/runcommand/onstart.sh" '/opt/retropie/configs/all/runcommand-onstart.sh'
  file_ln "$app_dir/bin/runcommand/onend.sh" '/opt/retropie/configs/all/runcommand-onend.sh'
}

uninstall() {
  restore '/opt/retropie/configs/all/runcommand-onstart.sh'
  restore '/opt/retropie/configs/all/runcommand-onend.sh'
}

"${@}"
