#!/bin/bash

##############
# Cache management
##############

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/common.sh"

usage() {
  echo "usage:"
  echo " $0 delete"
  echo " $0 sync_system_nointro_dats <system|all> <love_pack_pc_zip_file>"
  echo " $0 sync_system_metadata <system|all>"
  exit 1
}

delete() {
  # Remove all temporary cached data
  rm -rfv $tmp_dir/*
}

sync_system_nointro_dats() {
  [[ $# -ne 2 ]] && usage
  local system=$1
  local nointro_pack_path=$2

  while read -r dat_path; do
    local nointro_name=$(basename "$dat_path" .dat)
    local zip_filename=$(zipinfo -1 "$nointro_pack_path" | grep "$nointro_name" | head -n 1)

    if [ -n "$zip_filename" ]; then
      unzip -j "$nointro_pack_path" "$zip_filename" -d "$tmp_dir/"
      mv -v "$tmp_dir/$zip_filename" "$cache_dir/nointro/$nointro_name.dat"
    else
      echo "[WARN] No dat file found for $system"
    fi
  done < <(jq -r 'select(.romsets) | .romsets[] | select(.name == "nointro") | .resources.dat.source' "$app_dir/config/systems/$system/settings.json")
}

sync_system_metadata() {
  local system=$1
  local system_settings_file="$app_dir/config/systems/$system/settings.json"
  TMPDIR="$tmp_dir" python3 "$bin_dir/tools/scrape-metadata.py" "$system_settings_file" "${@:2}"
}

# Sync manuals to internetarchive
remote_sync_system_manuals() {
  local system=$1
  local archive_quality=${2:-original}
  local archive_id=${3:-retrokit-manualkit}

  # Download and process the manuals
  MANUALKIT_ARCHIVE=true "$bin_dir/setup.sh" install system-roms-manuals $system

  # Identify the post-processing base directory
  local postprocess_path_template=$(setting '.manuals.paths.postprocess')
  local postprocess_dir_template=$(dirname "$postprocess_path_template")
  local postprocess_dir=$(render_template "$postprocess_dir_template" system="$system")

  # Ensure the path actually exists and has files in it
  if [ -d "$postprocess_dir" ] && [ -n "$(ls -A "$postprocess_dir")" ]; then
    # Zip up the files and upload to internetarchive
    local zip_path="$tmp_ephemeral_dir/$system.zip"
    zip -j -db -r "$zip_path" "$postprocess_dir"/*.pdf
    ia upload "$archive_id" "$zip_path" --remote-name="$system/$system-$archive_quality.zip" --no-derive -H x-archive-keep-old-version:0
    rm "$zip_path"
  fi
}

main() {
  local action=$1

  if [[ "$action" == *system* ]]; then
    # Action is system-specific.  Either run against all systems
    # or against a specific system.
    local system=$2

    if [ -z "$system" ] || [ "$system" == 'all' ]; then
      while read system; do
        print_heading "Running $action for $system (${*:3})"
        "$action" "$system" "${@:3}"
      done < <(setting '.systems[] | select(. != "ports")')
    else
      print_heading "Running $action for $system (${*:3})"
      "$action" "$system" "${@:3}"
    fi
  else
    # Action is not system-specific.
    "$action" "${@:2}"
  fi
}

if [[ $# -lt 1 ]]; then
  usage
fi

main "$@"
