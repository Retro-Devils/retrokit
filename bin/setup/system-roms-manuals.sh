#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/system-common.sh"

manuals_download_path="$HOME/.emulationstation/downloaded_media/$system/manuals"

install() {
  local manuals_path="$system_config_dir/manuals.tsv"
  if [ ! -f "$manuals_path" ]; then
    echo 'No manuals configured'
    return
  fi

  # Ensure the target exists
  mkdir -pv "$manuals_download_path"

  # Define mappings to make lookups easy
  declare -A manual_urls
  while IFS=$'\t' read -r parent_title url; do
    manual_urls["$parent_title"]="$url"
  done < <(cat "$system_config_dir/manuals.tsv")

  declare -A installed_files
  declare -A installed_playlists
  while IFS=$'\t' read -r rom_name parent_title; do
    local manual_url=${manual_urls["$parent_title"]}
    if [ ! -f "$manual_url" ]; then
      echo "[$rom_name] No manual available"
      continue
    fi

    local extension="${manual_url##*.}"
    local download_path="$manuals_download_path/$parent_title.$extension"

    # Download the file if it doesn't already exist
    if [ ! -f "$download_path" ]; then
      download "$manual_url" "$download_path" || true
    fi

    if [ -f "$download_path" ]; then
      installed_files["$download_path"]=1

      # Symlink the rom to the downloaded file
      if [ "$rom_name" != "$parent_title" ]; then
        ln -fsv "$download_path" "$manuals_download_path/$rom_name.$extension"
        installed_files["$manuals_download_path/$rom_name.$extension"]=1
      fi

      # Add a playlist symlink if applicable
      local playlist_name=$(get_playlist_name "$rom_name")
      if has_playlist_config "$rom_name" && [ ! "${installed_playlists["$playlist_name"]}" ]; then
        ln -fsv "$download_path" "$manuals_download_path/$playlist_name.$extension"
        installed_playlists["$playlist_name"]=1
        installed_files["$manuals_download_path/$playlist_name.$extension"]=1
      fi
    fi

    while read -r path; do
      [ "${installed_files["$path"]}" ] || rm -v "$path"
    done < <(find "$manuals_download_path")
  done < <(romkit_cache_list | jq -r '[.name, .parent .title // .title] | @tsv')
}

uninstall() {
  rm -rfv "$manuals_download_path"
}

"$1" "${@:3}"
