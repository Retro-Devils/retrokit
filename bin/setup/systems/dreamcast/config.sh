#!/bin/bash

set -ex

system='dreamcast'
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../../system-common.sh"

config_path='/opt/retropie/emulators/redream/redream.cfg'

restore_config() {
  if has_backup "$config_path"; then
    # Keep track of the profiles since we don't want to lose those
    grep -E '^profile[0-9]+' "$config_path" > "$system_tmp_dir/profiles.cfg"

    restore "$config_path"

    # Merge the profiles back in
    crudini --inplace --merge "$config_path" < "$system_tmp_dir/profiles.cfg"
    rm "$system_tmp_dir/profiles.cfg"
  fi
}

install() {
  restore_config
  ini_merge "$system_config_dir/redream.cfg" "$config_path" restore=false
}

uninstall() {
  restore_config
}

"${@}"
