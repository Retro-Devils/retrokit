#!/bin/bash

set -e
[ "$DEBUG" == 'true' ] && set -x

##############
# Directories / Files
##############

setup_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
export app_dir=$(cd "$setup_dir/.." && pwd)
export bin_dir="$app_dir/bin"

# Import helper functions
source "$bin_dir/helpers/configs.sh"
source "$bin_dir/helpers/downloads.sh"
source "$bin_dir/helpers/emulationstation.sh"
source "$bin_dir/helpers/hooks.sh"
source "$bin_dir/helpers/logging.sh"
source "$bin_dir/helpers/profiles.sh"
source "$bin_dir/helpers/retropie_packages.sh"
source "$bin_dir/helpers/versions.sh"

# Define package directories
export cache_dir="$app_dir/cache"
export config_dir="$app_dir/config"
export data_dir="$app_dir/data"
export profiles_dir="$app_dir/profiles"
export tmp_dir="$app_dir/tmp"
export tmp_ephemeral_dir=$(mktemp -d -p "$tmp_dir")
trap 'rm -rf -- "$tmp_ephemeral_dir"' EXIT

# Read environment variable overrides.
# 
# We always load the root .env first since that may contain the `PROFILES` env override.
if [ -f "$app_dir/.env" ]; then
  source "$app_dir/.env"
fi
while read env_path; do
  source "$env_path"
done < <(each_path '{app_dir}/.env')

# Define settings file
export settings_file="$(mktemp -p "$tmp_ephemeral_dir")"
echo '{}' > "$settings_file"
if [ `command -v jq` ]; then
  json_merge '{config_dir}/settings.json' "$settings_file" backup=false >/dev/null
else
  # We haven't installed dependencies yet -- just use the default settings for now
  cp "$config_dir/settings.json" "$settings_file"
fi

##############
# Settings
##############

# Looks up a setting in the global settings file
setting() {
  jq -r "$1 | values" "$settings_file"
}

# Is the given setupmodule is enabled?
has_setupmodule() {
  [ $(setting ".setup | any(. == \"$1\")") == 'true' ]
}

##############
# Setup stubs
##############

setup() {
  local action=$1

  # Confirmation dialog
  if [[ "$action" =~ ^uninstall|remove$ ]] && [ "$CONFIRM" != 'false' ]; then
    read -p "Are you sure? (y/n) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo 'Aborted.'
      exit 1
    fi
  fi

  "${@}"
}

# Installs the setupmodule
install() {
  depends
  build
  configure
  clean
}

# Installs required system dependencies
depends() {
  return
}

# Creates any required artifacts and installs them to the filesystem
build() {
  return
}

# Configures the setupmodule
configure() {
  return
}

# Cleans up any unneeded files left behind
clean() {
  return
}

# Forces the setupmodule to be updated regardless of what's already been
# downloaded / installed
update() {
  FORCE_UPDATE=true
  install
}

# Uninstalls everything installed by the setupmodule, restoring configurations
# back to their original form
uninstall() {
  restore
  remove
}

# Restores the configurations modified by the setupmodule
restore() {
  return
}

# Removes any non-configuration files installed to the system
remove() {
  return
}

# Finds files that can be deleted from the filesystem.  This will only
# echo the `rm` commands -- you must run them.
vacuum() {
  return
}

# Restores the current setup module before RetroPie packages are reconfigured
before_retropie_reconfigure() {
  if [ "$setup_module_reconfigure_after_update" == 'true' ]; then
    restore
  fi
}

# Re-configures the current setup module after RetroPie packages were reconfigured
after_retropie_reconfigure() {
  if [ "$setup_module_reconfigure_after_update" == 'true' ]; then
    configure
  fi
}
