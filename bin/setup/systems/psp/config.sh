#!/bin/bash

set -ex

system='dreamcast'
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../../system-common.sh"

install() {
  ini_merge "$system_config_dir/ppsspp.ini" '/opt/retropie/configs/psp/PSP/SYSTEM/ppsspp.ini'
}

uninstall() {
  restore '/opt/retropie/configs/psp/PSP/SYSTEM/ppsspp.ini'
}

"${@}"
