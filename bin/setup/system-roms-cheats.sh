#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/system-common.sh"

cheat_database_path="$retroarch_config_dir/cheats"

install() {
  # Name of the cheats for this system
  local cheats_name=$(system_setting '.cheats')
  if [ -z "$cheats_name" ]; then
    echo 'No cheats configured'
    return
  fi

  # Load emulator data for finding the library_name
  load_emulator_data

  # Location of the cheats on the filesystem
  local cheat_database_path="$retroarch_config_dir/cheats"
  local source_cheats_dir="$cheat_database_path/$cheats_name"

  # Get cheat database path for this system
  local system_cheat_database_path=$(crudini --get "$retropie_system_config_dir/retroarch.cfg" '' 'cheat_database_path' 2>/dev/null | tr -d '"' || true)
  if [ -z "$system_cheat_database_path" ]; then
    system_cheat_database_path="$cheat_database_path"
  fi

  # Define mappings to make lookups easier and more reliable
  echo 'Loading list of available cheats...'
  declare -A cheat_mappings
  while IFS= read -r cheat_filename; do
    local cheat_name="${cheat_filename%.*}"
    local key="$(normalize_rom_name "$cheat_name")"
    local existing_mapping=${cheat_mappings["$key"]}

    # Only re-map if we need to.  This prioritizes exact matches.
    if [ -z "$existing_mapping" ]; then
      cheat_mappings["$key"]="$cheat_name"

      # In some cases, multiple ROMs are combined into a single cheat file
      while read -r sub_cheat_name; do
        key="$(normalize_rom_name "$sub_cheat_name")"
        existing_mapping=${cheat_mappings["$key"]}

        if [ -z "$existing_mapping" ]; then
          cheat_mappings["$key"]="$cheat_name"
        fi
      done < <(printf '%s\n' "${cheat_name// - /$'\n'}")
    fi
  done < <(ls "$source_cheats_dir" | awk '{ print length, $0 }' | sort -n -s | cut -d" " -f2-)

  # Link the named Retroarch cheats to the emulator in the system cheats namespace
  while IFS="^" read rom_name emulator; do
    emulator=${emulator:-default}
    local library_name=${emulators["$emulator/library_name"]}
    if [ -z "$library_name" ]; then
      # Not a libretro emulator
      continue
    fi

    # Ensure the target exists
    local target_cheats_dir="$system_cheat_database_path/$library_name"
    mkdir -p "$target_cheats_dir"

    # We can't just symlink to the source directory because the cheat filenames
    # don't always match the ROM names.  As a result, we need to try to do some
    # smart matching to find the corresponding cheat file.
    local cheat_name=${cheat_mappings["$(normalize_rom_name "$rom_name")"]}

    if [ -n "$cheat_name" ]; then
      local source_cheat_path="$source_cheats_dir/$cheat_name.cht"
      local target_cheat_path="$target_cheats_dir/$rom_name.cht"

      echo "Linking $source_cheat_path to $target_cheat_path"
      ln -fs "$source_cheat_path" "$target_cheat_path"
    fi
  done < <(romkit_cache_list | jq -r '[.name, .emulator] | join("^")')
}

uninstall() {
  local system_cheat_database_path=$(crudini --get "$retropie_system_config_dir/retroarch.cfg" '' 'cheat_database_path' 2>/dev/null | tr -d '"' || true)

  if [ -n "$system_cheat_database_path" ]; then
    # System has its own database path -- remove it
    echo "Deleting $system_cheat_database_path"
    rm -rf "$system_cheat_database_path"
  else
    # Remove cheats for each libretro core
    while IFS="$tab" read library_name; do
      echo "Deleting $cheat_database_path/$library_name"
      rm -rf "$cheat_database_path/$library_name"
    done < <(system_setting 'select(.emulators) | .emulators[] | select(.library_name) | .library_name')
  fi
}

"$1" "${@:3}"
