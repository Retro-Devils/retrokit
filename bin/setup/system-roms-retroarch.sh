#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/system-common.sh"

setup_module_id='system-roms-retroarch'
setup_module_desc='Configure game-specific retroarch configurations and core options'

retroarch_config_dir=$(get_retroarch_path 'rgui_config_directory')
retroarch_remapping_dir=$(get_retroarch_path 'input_remapping_directory')
retroarch_remapping_dir=${retroarch_remapping_dir%/}

configure() {
  restore

  __load_multitap_titles
  __load_lightgun_titles
  __configure_retroarch_configs
  __configure_retroarch_remappings
  __configure_retroarch_core_options
}

# Get the list of games which support multi-tap devices
__load_multitap_titles() {
  declare -Ag multitap_titles

  while read -r rom_title; do
    multitap_titles["$rom_title"]=1
  done < <(each_path '{config_dir}/emulationstation/collections/custom-Multitap.tsv' cat '{}' | grep -E "^$system"$'\t' | cut -d$'\t' -f 2)
}

# Get the list of games which support lightgun devices
__load_lightgun_titles() {
  declare -Ag lightgun_titles

  while read -r rom_title; do
    lightgun_titles["$rom_title"]=1
  done < <(each_path '{config_dir}/emulationstation/collections/custom-Lightguns.tsv' cat '{}' | grep -E "^$system"$'\t' | cut -d$'\t' -f 2)
}

# Game-specific retroarch configuration overrides
# 
# Note that overrides get defined under the retroarch emulator's directory
# instead of the RetroPie roms directory.  This is because the `--appendconfig`
# option that's used by RetroPie cannot override configurations defined in an
# existing built-in RetroArch configuration, which makes configurations a pain
# to manage otherwise.
__configure_retroarch_configs() {
  local rom_dirs=$(system_setting 'select(.roms) | .roms.dirs[] | .path')
  if [ -z "$rom_dirs" ]; then
    return
  fi

  local has_multitap_config=$(any_path_exists '{system_config_dir}/retroarch-multitap.cfg' && echo 'true')
  local has_lightgun_config=$(any_path_exists '{system_config_dir}/retroarch-lightgun.cfg' && echo 'true')

  # Merge in rom-specific overrides
  while IFS=$'\t' read -r rom_name rom_filename group_title core_name core_option_prefix library_name override_file; do
    # Retroarch emulator-specific config
    local emulator_config_dir="$retroarch_config_dir/$library_name"
    mkdir -p "$emulator_config_dir"

    local target_path="$emulator_config_dir/$rom_name.cfg"

    # Copy over multitap overrides
    if [ "$has_multitap_config" == 'true' ] && [ "${multitap_titles["$group_title"]}" ]; then
      ini_merge '{system_config_dir}/retroarch-multitap.cfg' "$target_path" backup=false
    fi

    # Copy over lightgun overrides
    if [ "$has_lightgun_config" == 'true' ] && [ "${lightgun_titles["$group_title"]}" ]; then
      ini_merge '{system_config_dir}/retroarch-lightgun.cfg' "$target_path" backup=false
    fi

    if [ -n "$override_file" ]; then
      ini_merge "$override_file" "$target_path" backup=false
    fi
  done < <(__list_libretro_roms 'cfg')
}

# Games-specific controller mapping overrides
__configure_retroarch_remappings() {
  while IFS=$'\t' read -r rom_name rom_filename group_title core_name core_option_prefix library_name override_file; do
    if [ -z "$override_file" ]; then
      continue
    fi

    # Emulator-specific remapping directory
    local emulator_remapping_dir="$retroarch_remapping_dir/$library_name"
    mkdir -p "$emulator_remapping_dir"

    ini_merge "$override_file" "$emulator_remapping_dir/$rom_name.rmp" backup=false overwrite=true
  done < <(__list_libretro_roms 'rmp')
}

# Game-specific libretro core overrides
# (https://retropie.org.uk/docs/RetroArch-Core-Options/)
__configure_retroarch_core_options() {
  local system_core_options_path=$(get_retroarch_path 'core_options_path')

  local has_multitap_config=$(any_path_exists '{system_config_dir}/retroarch-core-options-multitap.cfg' && echo 'true')
  local has_lightgun_config=$(any_path_exists '{system_config_dir}/retroarch-core-options-lightgun.cfg' && echo 'true')

  while IFS=$'\t' read -r rom_name rom_filename group_title core_name core_option_prefix library_name override_file; do
    if [ -z "$override_file" ] && { [ "$has_multitap_config" != 'true' ] || [ ! "${multitap_titles["$group_title"]}" ]; } && { [ "$has_lightgun_config" != 'true' ] || [ ! "${lightgun_titles["$group_title"]}" ]; }; then
      # No overrides to define at the rom-level
      continue
    fi

    # Retroarch emulator-specific config
    local emulator_config_dir="$retroarch_config_dir/$library_name"
    mkdir -p "$emulator_config_dir"

    # Copy over existing core overrides so we don't just get the
    # core defaults
    local target_path="$emulator_config_dir/$rom_name.opt"
    echo "Merging $core_option_prefix system overrides to $target_path"
    cp -v "$system_core_options_path" "$target_path"

    # Copy over multitap overrides
    if [ "$has_multitap_config" == 'true' ] && [ "${multitap_titles["$group_title"]}" ]; then
      ini_merge '{system_config_dir}/retroarch-core-options-multitap.cfg' "$target_path" backup=false
    fi

    # Copy over lightgun overrides
    if [ "$has_lightgun_config" == 'true' ] && [ "${lightgun_titles["$group_title"]}" ]; then
      ini_merge '{system_config_dir}/retroarch-core-options-lightgun.cfg' "$target_path" backup=false
    fi

    # Select options specific to this core
    sed -i -n "/^$core_option_prefix[\-_]/p" "$target_path"

    # Merge in game-specific overrides
    if [ -n "$override_file" ]; then
      ini_merge "$override_file" "$target_path" backup=false
    fi
  done < <(__list_libretro_roms 'opt')
}

__list_libretro_roms() {
  local extension=$1

  # Load core/library info for the emulators
  load_emulator_data

  # Load which overrides are available
  declare -Ag override_files
  while read override_file; do
    local override_name=$(basename "$override_file" ".$extension")
    override_files["$override_name"]=$override_file
  done < <(each_path '{system_config_dir}/retroarch' find '{}' -name "*.$extension")

  # Track which playlists we've installed so we don't do it twice
  declare -A installed_playlists

  while IFS=» read -r rom_name disc title playlist_name parent_name parent_disc parent_title rom_path emulator; do
    # Look up emulator attributes as those are the important ones
    # for configuration purposes
    emulator=${emulator:-default}
    local core_name=${emulators["$emulator/core_name"]}
    local core_option_prefix=${emulators["$emulator/core_option_prefix"]}
    local library_name=${emulators["$emulator/library_name"]}
    if [ -z "$core_name" ] || [ -z "$library_name" ]; then
      continue
    fi

    local group_title=${parent_title:-$title}

    local target_name
    local target_filename
    if [ -n "$playlist_name" ]; then
      if [ "${installed_playlists["$playlist_name"]}" ]; then
        # We've already processed this playlist -- don't do it again
        continue
      fi

      # Generate a config for the playlist
      installed_playlists["$playlist_name"]=1
      target_name=$playlist_name
      target_filename="$playlist_name.m3u"
    else
      # Generate a config for single-disc games
      target_name=$rom_name
      target_filename=${rom_path##*/}
    fi

    # Find a file for either the rom or its parent.  Priority order:
    # * ROM Name
    # * ROM Disc Name
    # * ROM Title
    # * ROM Playlist Name
    local override_file=""
    local filename
    for filename in "$rom_name" "$disc" "$title" "$playlist_name" "$parent_name" "$parent_disc" "$parent_title"; do
      if [ -n "$filename" ]; then
        override_file=${override_files["$filename"]}
        if [ -n "$override_file" ]; then
          break
        fi
      fi
    done

    echo "$target_name"$'\t'"$target_filename"$'\t'"$group_title"$'\t'"$core_name"$'\t'"$core_option_prefix"$'\t'"$library_name"$'\t'"$override_file"
  done < <(romkit_cache_list | jq -r '[.name, .disc, .title, .playlist.name, .parent.name, .parent.disc, .parent.title, .path, .emulator] | join("»")')
}

restore() {
  while read -r library_name; do
    local emulator_config_dir="$retroarch_config_dir/$library_name"
    if [ -d "$emulator_config_dir" ]; then
      # Remove core options
      find "$emulator_config_dir" -name '*.opt' -exec rm -fv '{}' +

      # Remove retroarch config overrides
      while read rom_config_path; do
        if grep -qvF input_overlay "$rom_config_path"; then
          # Keep input_overlay as that's managed by system-roms-overlays
          echo "Removing overrides from $rom_config_path"
          sed -i '/^input_overlay[ =]/!d' "$rom_config_path"

          if [ ! -s "$rom_config_path" ]; then
            rm -fv "$rom_config_path"
          fi
        fi
      done < <(find "$emulator_config_dir" -name '*.cfg' -not -name "$library_name.cfg")
    fi

    # Remove retroarch mappings
    local emulator_remapping_dir="$retroarch_remapping_dir/$library_name"
    if [ -d "$emulator_remapping_dir" ]; then
      find "$emulator_remapping_dir" -name '*.rmp' -not -name "$library_name.rmp*" -exec rm -fv '{}' +
    fi
  done < <(get_core_library_names)
}

setup "$1" "${@:3}"
