#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

retroarch_config_path='/opt/retropie/configs/all/retroarch.cfg'
retroarch_core_options_path='/opt/retropie/configs/all/retroarch-core-options.cfg'

restore_config() {
  if has_backup_file "$retroarch_config_path"; then
    if [ -f "$retroarch_config_path" ]; then
      # Keep track of the inputs since we don't want to lose those
      grep -E '^input_.+' "$retroarch_config_path" > "$tmp_ephemeral_dir/retroarch-inputs.cfg"

      restore_file "$retroarch_config_path" "${@}"

      # Merge the inputs back in
      crudini --merge --inplace "$retroarch_config_path" < "$tmp_ephemeral_dir/retroarch-inputs.cfg"
      rm "$tmp_ephemeral_dir/retroarch-inputs.cfg"
    else
      restore_file "$retroarch_config_path" "${@}"
    fi
  fi
}

install() {
  restore_config
  ini_merge "$config_dir/retroarch/retroarch.cfg" "$retroarch_config_path" restore=false
  ini_merge "$config_dir/retroarch/retroarch-core-options.cfg" "$retroarch_core_options_path"
}

uninstall() {
  restore_file "$retroarch_core_options_path" delete_src=true
  restore_config delete_src=true
}

"${@}"
