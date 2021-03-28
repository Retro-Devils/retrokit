#!/bin/bash

##############
# System: Arcade
##############

set -ex

dir=$( dirname "$0" )
. $dir/common.sh

# System info
system="arcade"
init "$system"

# Directories
config_dir="$app_dir/config/systems/$system"
settings_file="$config_dir/settings.json"
system_tmp_dir="$tmp_dir/arcade"
mkdir -p "$system_tmp_dir"

# Configurations
retroarch_config="/opt/retropie/configs/$system/retroarch.cfg"
emulators_config="/opt/retropie/configs/$system/emulators.cfg"
emulators_retropie_config="/opt/retropie/configs/all/emulators.cfg"

# Support files
roms_dir="$HOME/RetroPie/roms/$system"
roms_all_dir="$roms_dir/-ALL-"
compatibility_file="$system_tmp_dir/compatibility.tsv"
categories_file="$system_tmp_dir/catlist.ini"
categories_flat_file="$categories_file.flat"
languages_file="$system_tmp_dir/languages.ini"
languages_flat_file="$languages_file.flat"
ratings_file="$system_tmp_dir/ratings.ini"
ratings_flat_file="$ratings_file.flat"

# Filters: Overrides
favorites=$(setting_regex ".roms.favorites")

# Filters: Blocklists
blocklists_clones=$(setting ".roms.blocklists.clones")
blocklists_languages=$(setting_regex ".roms.blocklists.languages")
blocklists_categories=$(setting_regex ".roms.blocklists.categories")
blocklists_ratings=$(setting_regex ".roms.blocklists.ratings")
blocklists_keywords=$(setting_regex ".roms.blocklists.keywords")
blocklists_flags=$(setting_regex ".roms.blocklists.flags")
blocklists_controls=$(setting_regex ".roms.blocklists.controls")
blocklists_names=$(setting_regex ".roms.blocklists.names")

# Filters: Allowlists
allowlists_clones=$(setting ".roms.allowlists.clones")
allowlists_languages=$(setting_regex ".roms.allowlists.languages")
allowlists_categories=$(setting_regex ".roms.allowlists.categories")
allowlists_ratings=$(setting_regex ".roms.allowlists.ratings")
allowlists_keywords=$(setting_regex ".roms.allowlists.keywords")
allowlists_flags=$(setting_regex ".roms.allowlists.flags")
allowlists_controls=$(setting_regex ".roms.allowlists.controls")
allowlists_names=$(setting_regex ".roms.allowlists.names")

# XSLT conditions for optimizing what we index
xslt_opt_conditions=''
if [ "$blocklists_clones" == "true" ] || [ "$allowlists_clones" == "false" ]; then
  if [ -n "$favorites" ] ; then
    xslt_opt_conditions=" or (@name='$(setting ".roms.favorites[]" | sed ':a; N; $!ba; s/\n/'"'"' or @name=\'"'"'/g')')"
  fi
  xslt_opt_conditions=" and (not(@cloneof)$xslt_opt_conditions)"
fi

# XSLT for grabbing data from DAT files
roms_dat_xslt='''<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:exslt="http://exslt.org/common" version="1.0" extension-element-prefixes="exslt">
  <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz'" />
  <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />
  <xsl:output omit-xml-declaration="yes" indent="no"/>
  <xsl:template match="/">
    <xsl:for-each select="/*/*[rom and not(@ismechanical = 'yes')'''"$xslt_opt_conditions"''']">
      <xsl:value-of select="@name"/>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:value-of select="translate(description/text(), $uppercase, $lowercase)"/>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:value-of select="@romof"/>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:value-of select="@cloneof"/>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:value-of select="@sampleof"/>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="rom[@merge]">
        <xsl:value-of select="@merge"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="rom[@merge]">
        <xsl:value-of select="@name"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="rom[not(@merge)]">
        <xsl:value-of select="@name"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="device_ref">
        <xsl:value-of select="@name"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="disk">
        <xsl:value-of select="@name"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xBB;</xsl:text>
      <xsl:for-each select="input/control">
        <xsl:value-of select="@type"/><xsl:text>,</xsl:text>
      </xsl:for-each>
      <xsl:text>&#xa;</xsl:text>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
'''

# In-memory mappings
declare -A roms_compatibility
declare -A roms_categories
declare -A roms_languages
declare -A roms_ratings

# Set data
declare reference_set_name
declare -A sets
declare -A emulators
declare -A roms
declare -a rom_names

usage() {
  echo "usage: $0"
  exit 1
}

setup() {
  # Input Lag
  crudini --set "$retroarch_config" '' 'run_ahead_enabled' '"true"'
  crudini --set "$retroarch_config" '' 'run_ahead_frames' '"1"'
  crudini --set "$retroarch_config" '' 'run_ahead_secondary_instance' '"true"'

  # Install emulators
  while IFS="$tab" read -r emulator build branch is_default; do
    if [ "${build:-binary}" == "binary" ]; then
      # Binary install
      sudo ~/RetroPie-Setup/retropie_packages.sh "$emulator" _binary_
    else
      # Source install
      if [ -n "$branch" ]; then
        # Set to correct branch
        local setup_file="$HOME/RetroPie-Setup/scriptmodules/libretrocores/$emulator.sh"
        if [ ! -s "$setup_file.orig" ]; then
          cp "$setup_file" "$setup_file.orig"
        fi

        sed -i "s/.git master/.git $branch/g" "$setup_file"
      fi

      sudo ~/RetroPie-Setup/retropie_packages.sh "$emulator" _source_
    fi

    # Set default
    if [ "$is_default" == "true" ]; then
      crudini --set "$emulators_config" '' 'default' "\"$emulator\""
    fi
  done < <(setting ".emulators | to_entries[] | [.key, .value.build, .value.branch, .value.default] | @tsv")
}

# Clean the configuration key used for defining ROM-specific emulator options
# 
# Implementation pulled from retropie
clean_emulator_config_key() {
  local name="$1"
  name="${name//\//_}"
  name="${name//[^a-zA-Z0-9_\-]/}"
  echo "$name"
}

# Load information about the sets from which we'll pull down ROMs
load_sets() {
  echo "Loading sets..."

  # Read configured sets
  while read -r set_name; do
    # Load the set
    while IFS="$tab" read -r key value; do
      sets["$set_name/$key"]="$value"
    done < <(setting ".roms.sets.\"$set_name\" | to_entries[] | [.key, .value] | @tsv")

    # Load emulator info
    emulators["${sets["$set_name/emulator"]}/set_name"]="$set_name"
  done < <(setting '.roms.sets | keys[]')
}

index_set_dats() {
  echo "Indexing set dats... (this takes a while)"

  while read -r set_name; do
    local set_core=${sets["$set_name/core"]}
    local set_dat_url=$(set_asset_url "$set_name" "dat")
    local set_is_reference=${sets["$set_name/reference"]}
    local roms_core_dir="$roms_dir/.$set_core"
    local target_dat_file="$roms_core_dir/.dat"
    mkdir -p "$roms_core_dir"

    if [ ! -s "$target_dat_file" ]; then
      download_file "$set_dat_url" "$target_dat_file"
    fi

    if [ ! -s "$target_dat_file.index" ]; then
      xmlstarlet tr <(echo "$roms_dat_xslt") "$target_dat_file" > "$target_dat_file.index"
    fi

    # Find the list of roms that are downloadable
    while IFS="»" read -r name description romof cloneof sampleof parent_source_files parent_target_files files device_refs disks controls; do
      if [ -n "$set_is_reference" ]; then
        reference_set_name="$set_name"
        rom_names+=("$name")
      fi

      roms["$set_name/$name/description"]="$description"
      if [ -z "$cloneof" ]; then
        roms["$set_name/$name/bios"]="$romof"
      fi
      roms["$set_name/$name/parent"]="$cloneof"
      roms["$set_name/$name/sampleof"]="$sampleof"
      roms["$set_name/$name/parent_source_files"]="${parent_source_files%,*}"
      roms["$set_name/$name/parent_target_files"]="${parent_target_files%,*}"
      roms["$set_name/$name/files"]="${files%,*}"
      roms["$set_name/$name/devices"]="${device_refs%,*}"
      roms["$set_name/$name/disks"]="${disks%,*}"
      roms["$set_name/$name/controls"]="${controls%,*}"
    done < "$target_dat_file.index"
  done < <(setting '.roms.sets | keys[]')
}

# Build the base url for the given set / asset
set_asset_url() {
  local set_name="$1"
  local asset_name="$2"
  local set_url=${sets["$set_name/url"]}
  local asset_path=${sets["$set_name/$asset_name"]}

  if [[ "$asset_path" =~ ^http ]]; then
    echo "$asset_path"
  else
    echo "$set_url$asset_path"
  fi
}

# Download external support files needed for filtering purposes
download_support_files() {
  echo "Downloading support files..."

  # Load support file settings
  declare -A support_files
  while IFS="$tab" read -r name url file; do
    support_files["$name/url"]="$url"
    support_files["$name/file"]="$file"
  done < <(setting ".support_files | to_entries[] | [.key, .value.url, .value.file] | @tsv")

  # Download languages file
  if [ ! -s "$languages_flat_file" ]; then
    if [ ! -s "$languages_file.zip" ]; then
      download_file "${support_files['languages/url']}" "$languages_file.zip"
    fi
    unzip -p "$languages_file.zip" "${support_files['languages/file']}" > "$languages_file"
    crudini --get --format=lines "$languages_file" > "$languages_flat_file"
  fi

  # Download categories file
  if [ ! -s "$categories_flat_file" ]; then
    if [ ! -s "$categories_file.zip" ]; then
      download_file "${support_files['categories/url']}" "$categories_file.zip"
    fi
    unzip -p "$categories_file.zip" "${support_files['categories/file']}" > "$categories_file"
    crudini --get --format=lines "$categories_file" > "$categories_flat_file"
  fi

  # Download compatibility file
  if [ ! -s "$compatibility_file" ]; then
    download_file "${support_files['compatibility/url']}" "$compatibility_file"
  fi

  # Download ratings file
  if [ ! -s "$ratings_flat_file" ]; then
    if [ ! -s "$ratings_file.zip" ]; then
      download_file "${support_files['ratings/url']}" "$ratings_file.zip"
    fi
    unzip -p "$ratings_file.zip" "${support_files['ratings/file']}" > "$ratings_file"
    crudini --get --format=lines "$ratings_file" > "$ratings_flat_file"
  fi
}

load_support_files() {
  download_support_files

  echo "Loading emulator compatiblity..."
  while IFS="$tab" read -r rom_name emulator; do
    roms_compatibility["$rom_name"]="$emulator"
  done < <(cat "$compatibility_file" | awk -F"$tab" "{print \$1\"$tab\"tolower(\$3)}")

  while IFS="$tab" read -r rom_name emulator; do
    roms_compatibility["$rom_name"]="$emulator"
  done < <(setting ".roms.emulator_overrides | to_entries[] | [.key, .value] | @tsv")

  echo "Loading categories..."
  while IFS="$tab" read -r rom_name category; do
    roms_categories["$rom_name"]="$category"
  done < <(cat "$categories_flat_file" | grep Arcade | sed "s/^\[ \(.*\) \] \(.*\)$/\2$tab\1/g")

  echo "Loading languages..."
  while IFS="$tab" read -r rom_name language; do
    roms_languages["$rom_name"]="$language"
  done < <(cat "$languages_flat_file" | sed "s/^\[ \(.*\) \] \(.*\)$/\2$tab\1/g")

  echo "Loading ratings..."
  while IFS="$tab" read -r rom_name rating; do
    roms_ratings["$rom_name"]="$rating"
  done < <(cat "$ratings_flat_file" | sed "s/^\[ \(.*\) \] \(.*\)$/\2$tab\1/g")
}

# Reset the list of ROMs that are visible
reset_filtered_roms() {
  if [ -d "$roms_all_dir" ]; then
    find "$roms_all_dir/" -maxdepth 1 -type l -exec rm "{}" \;
  fi
}

# Checks whether the target rom/machine already contains all of the files for the
# source rom/machine
needs_merge() {
  # Arguments
  local set_name="$1"
  local source="$2"
  local target="$3"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}
  local roms_emulator_dir="$roms_dir/.$set_core"

  # Files to compare
  local source_files="${roms["$set_name/$source/files"]}"
  local target_existing_files="$(zipinfo -1 "$roms_emulator_dir/$target.zip" | paste -sd ' ')"

  for file in ${source_files//,/ }; do
    if [[ " $target_existing_files " != *" $file " ]]; then
      return 0
    fi
  done

  return 1
}

merge_rom() {
  # Arguments
  local set_name="$1"
  local source="$2"
  local target="$3"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}
  local roms_emulator_dir="$roms_dir/.$set_core"
  local roms_tmp_dir="$roms_emulator_dir/tmp"
  mkdir -p "$roms_tmp_dir"

  # Target rom file
  local target_file="$roms_emulator_dir/$target.zip"
  local target_existing_files=$(zipinfo -1 "$target_file" | paste -sd ' ')

  # Source rom file
  local source_file="$roms_emulator_dir/$source.zip"
  local source_dir=""
  if [ $# -gt 3 ]; then local "${@:4}"; fi

  local target_parent="${roms["$set_name/$target/parent"]}"
  if [ "$source" == "$target_parent" ]; then
    # Merge names (source => target)
    local parent_source_files=(${roms["$set_name/$target/parent_source_files"]//,/ })
    local parent_target_files=(${roms["$set_name/$target/parent_target_files"]//,/ })

    # Merge files from the parent using the name in the target
    for i in ${!parent_source_files[@]}; do
      local parent_source_file="${parent_source_files[$i]}"
      local parent_target_file="${parent_target_files[$i]}"

      if [[ " $target_existing_files " != *" $file " ]]; then
        # File doesn't exist: add it
        local tmp_file="$roms_tmp_dir/$parent_target_file"
        unzip -p "$source_file" "$parent_source_file" > "$tmp_file"
        zip -j "$target_file" "$tmp_file"
        rm "$tmp_file"
      fi
    done
  else
    # Copy based on the names in the zip file
    if [ -n "$source_dir" ]; then
      # Merge just the subfolder (we are copying files for a clone in a merged romset)
      while read file; do
        if [[ " $target_existing_files " != *" $file " ]]; then
          # File doesn't exist: add it
          local tmp_file="$roms_tmp_dir/$file"
          unzip -p "$source_file" "$source_dir/$file" > "$tmp_file"
          zip -j "$target_file" "$tmp_file"
          rm "$tmp_file"
        fi
      done < <(zipinfo -1 "$source_file" | grep -oP "^$source_dir\K(.+)$" )
    else
      # Merge everything (we are copying files from a bios/device)
      zipmerge -S "$target_file" "$source_file"
    fi
  fi
}

install_rom_nonmerged_file() {
  # Arguments
  local rom_name="$1"
  local emulator="$2"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}
  local set_format=${sets["$set_name/format"]}

  # Set: ROMs
  local roms_set_url=$(set_asset_url "$set_name" "roms")
  local roms_emulator_dir="$roms_dir/.$set_core"
  local rom_emulator_file="$roms_emulator_dir/$rom_name.zip"
  mkdir -p "$roms_emulator_dir"

  local mtime_before=$(stat --format='%.Y' "$rom_emulator_file" || true)

  # Install ROM asset
  if [ ! -s "$rom_emulator_file" ]; then
    local parent_rom_name=${roms["$set_name/$rom_name/parent"]}

    if [[ "$set_format" == "merged" ]]; then
      # Download parent merged rom (contains children)
      local merged_rom_name="${parent_rom_name:-$rom_name}"
      local merged_rom_emulator_file="$roms_emulator_dir/$merged_rom_name.merged.zip"
      if [ ! -s "$merged_rom_emulator_file" ]; then
        download_file "$roms_set_url$merged_rom_name.zip" "$merged_rom_emulator_file"
      fi

      # Create empty rom
      echo -ne '\x50\x4b\x05\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "$rom_emulator_file"

      if [ -n "$parent_rom_name" ]; then
        # Merge files from parent
        merge_rom "$set_name" "$parent_rom_name" "$rom_name" source_file="$merged_rom_emulator_file"
      fi

      # Merge files for the rom
      merge_rom "$set_name" "$rom_name" "$rom_name" source_file="$merged_rom_emulator_file"
    else
      # Download non-merged / split rom
      download_file "$roms_set_url$rom_name.zip" "$rom_emulator_file"

      if [ "$set_format" == "split" ] && [ -n "$parent_rom_name" ]; then
        # Download the parent and merge it
        local parent_rom_emulator_file="$roms_set_url$parent_rom_name.zip"

        if [ ! -s "$parent_rom_emulator_file" ]; then
          download_file "$roms_set_url$parent_rom_name.zip" "$parent_rom_name"
        fi

        merge_rom "$set_name" "$parent_rom_name" "$rom_name"
      fi
    fi
  fi

  # Merge BIOS (if necessary)
  local bios_rom_name=${roms["$set_name/$rom_name/bios"]}
  if [ -n "$bios_rom_name" ] && needs_merge "$set_name" "$bios_rom_name" "$rom_name"; then
    local bios_emulator_file="$roms_emulator_dir/$bios_rom_name.zip"

    if [ ! -s "$bios_emulator_file" ]; then
      download_file "$roms_set_url$bios_rom_name.zip" "$bios_emulator_file"
    fi

    merge_rom "$set_name" "$bios_rom_name" "$rom_name"
  fi

  # Merge devices (if necessary)
  devices=${roms["$set_name/$rom_name/devices"]}
  for device_name in ${devices//,/ }; do
    if [ -n "${roms["$set_name/$device_name/files"]}" ] && needs_merge "$set_name" "$device_name" "$rom_name"; then
      local device_emulator_file="$roms_emulator_dir/$device_name.zip"
      if [ ! -s "$device_emulator_file" ]; then
        download_file "$roms_set_url$device_name.zip" "$device_emulator_file"
      fi

      merge_rom "$set_name" "$device_name" "$rom_name"
    fi
  done

  # Create ZIP at target if it's changed
  local mtime_after=$(stat --format='%.Y' "$rom_emulator_file")
  if [ "$mtime_before" != "$mtime_after" ]; then
    trrntzip "$rom_emulator_file"
  fi
}

install_rom_disks() {
  # Arguments
  local rom_name="$1"
  local emulator="$2"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}

  # Disks
  local disks_set_url=$(set_asset_url "$set_name" "disks")
  local disk_emulator_dir="$roms_dir/.chd/$rom_name"

  # Install
  local disks=${roms["$set_name/$rom_name/disks"]}
  for disk_name in ${disks//,/ }; do
    mkdir -p "$disk_emulator_dir"
    local disk_emulator_file="$disk_emulator_dir/$disk_name.chd"

    download_file "$disks_set_url$rom_name/$disk_name.chd" "$disk_emulator_file" || return 1
  done
}

install_rom_samples() {
  # Arguments
  local rom_name="$1"
  local emulator="$2"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}

  # Samples
  local samples_set_url=$(set_asset_url "$set_name" "samples")
  local samples_target_dir="$HOME/RetroPie/BIOS/$set_core/samples"
  mkdir -p "$samples_target_dir"

  # Install
  local sample_name=${roms["$set_name/$rom_name/sample"]}
  if [ -n "$sample_name" ]; then
    local sample_file="$samples_target_dir/$sample_name.zip"

    download_file "$samples_set_url$sample_name.zip" "$sample_file" || return 1
  fi
}

activate_rom() {
  # Arguments
  local rom_name="$1"
  local emulator="$2"

  # Set info
  local set_name=${emulators["$emulator/set_name"]}
  local set_core=${sets["$set_name/core"]}
  local rom_emulator_file="$roms_dir/.$set_core/$rom_name.zip"
  local disk_emulator_dir="$roms_dir/.chd/$rom_name"

  # Target
  local rom_target_file="$roms_all_dir/$rom_name.zip"
  local disk_target_dir="$roms_all_dir/$rom_name"
  mkdir -p "$roms_all_dir"

  # Link to -ALL- (including disk)
  ln -fs "$rom_emulator_file" "$rom_target_file"
  if [ -d "$disk_emulator_dir" ]; then
    ln -fs "$disk_emulator_dir" "$disk_target_dir"
  fi
}

# Installs a rom for a specific emulator
install_rom() {
  install_rom_nonmerged_file "${@}"
  install_rom_disks "${@}"
  install_rom_samples "${@}"
  activate_rom "${@}"

  # Remove TorrentZip logs
  rm -f "$(pwd)/*log"
}

install_roms() {
  for rom_name in "${rom_names[@]}"; do
    # Read rom attributes
    local emulator=${roms_compatibility["$rom_name"]}
    local set_name=${emulators["$emulator/set_name"]}
    local is_clone=${roms["$reference_set_name/$rom_name/cloneof"]}
    local description=${roms["$reference_set_name/$rom_name/description"]}
    local controls=${roms["$reference_set_name/$rom_name/controls"]}
    local category=${roms_categories["$rom_name"]}
    local language=${roms_languages["$rom_name"]}
    local rating=${roms_ratings["$rom_name"]}

    # Compatible / Runnable roms
    if [ -z "$emulator" ]; then
      echo "[Skip] $rom_name (poor compatibility)"
      continue
    fi

    # ROMs with sets
    if [ -z "$set_name" ]; then
      echo "[Skip] $rom_name (no set for emulator)"
      continue
    fi

    # Always allow favorites regardless of filter
    if filter_regex "" "$favorites" "$rom_name" exact_match=true; then
      # Is Clone
      if filter_regex "$blocklists_clones" "$allowlists_clones" "$is_clone"; then
        echo "[Skip] $rom_name (clone)"
        continue
      fi

      # Language
      if filter_regex "$blocklists_languages" "$allowlists_languages" "$language"; then
        echo "[Skip] $rom_name (language)"
        continue
      fi

      # Category
      if filter_regex "$blocklists_categories" "$allowlists_categories" "$category"; then
        echo "[Skip] $rom_name (category)"
        continue
      fi

      # Rating
      if filter_regex "$blocklists_ratings" "$allowlists_ratings" "$rating"; then
        echo "[Skip] $rom_name (rating)"
        continue
      fi

      # Keywords
      if filter_regex "$blocklists_keywords" "$allowlists_keywords" "$description"; then
        echo "[Skip] $rom_name (description)"
        continue
      fi

      # Flags
      local flags=$(echo "$description" | grep -oP "\(\K[^\)]+" || true)
      if filter_regex "$blocklists_flags" "$allowlists_flags" "$flags"; then
        echo "[Skip] $rom_name (flags)"
        continue
      fi

      # Controls
      if filter_all_in_list "$blocklists_controls" "$allowlists_controls" "$controls"; then
        echo "[Skip] $rom_name (controls)"
        continue
      fi

      # Name
      if filter_regex "$blocklists_names" "$allowlists_names" "$rom_name" exact_match=true; then
        echo "[Skip] $rom_name (name)"
        continue
      fi
    fi

    # Install
    echo "[Install] $rom_name"
    install_rom "$rom_name" "$emulator" || echo "Failed to download: $rom_name ($emulator)"
  done
}

set_default_emulators() {
  # Merge emulator configurations
  # 
  # This is done at the end in one batch because it's a bit slow otherwise
  crudini --merge "$emulators_retropie_config" < <(
    for rom_name in "${!emulators[@]}"; do
      echo "$(clean_emulator_config_key "arcade_$rom_name") = \"${emulators["$rom_name"]}\""
    done
  )
}

# Organize ROMs based on favorites
organize_system() {
  # Clear existing ROMs
  find "$roms_dir/" -maxdepth 1 -type l -exec rm "{}" \;

  # Add based on favorites
  while read rom; do
    local source_file="$roms_all_dir/$rom.zip"
    local source_disk_dir="$roms_all_dir/$rom"
    local target_file="$roms_dir/$rom.zip"
    local target_disk_dir="$roms_dir/$rom"

    ln -fs "$source_file" "$target_file"

    # Create link for drive as well (if applicable)
    if [ -d "$source_disk_dir" ]; then
      ln -fs "$source_disk_dir" "$target_disk_dir"
    fi
  done < <(setting ".roms.favorites[]")
}

# This is strongly customized due to the nature of Arcade ROMs
# 
# MAYBE it could be generalized, but I'm not convinced it's worth the effort.
download() {
  load_sets
  index_set_dats
  load_support_files
  reset_filtered_roms
  install_roms
  set_default_emulators
  organize_system "$system"
  scrape_system "$system" "screenscraper"
  # scrape_system "$system" "arcadedb"
  build_gamelist "$system"
  theme_system "MAME"
}

if [[ $# -lt 1 ]]; then
  usage
fi

command="$1"
shift
"$command" "$@"
