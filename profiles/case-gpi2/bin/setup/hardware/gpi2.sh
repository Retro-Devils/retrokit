#!/bin/bash

. "$bin_dir/common.sh"

setup_module_id='hardware/gpi2'
setup_module_desc='GPi2 management utilities'

build() {
  __build_overlays
  __build_port_shortcuts
}

__build_overlays() {
  local patches_zip="$tmp_dir/gpi_case2_patch.zip"
  local overlay_base_path='GPi_Case2_patch_retropie/patch_files/overlays'
  download 'https://github.com/RetroFlag/GPiCase2-Script/raw/main/GPi_Case2_patch.zip' "$patches_zip"
  unzip -o "$patches_zip" "$overlay_base_path/*" -d "$tmp_ephemeral_dir/"

  # Screen overlay
  file_cp "$tmp_ephemeral_dir/$overlay_base_path/dpi24.dtbo" /boot/overlays/dpi24.dtbo as_sudo=true

  # Audio overlay
  file_cp "$tmp_ephemeral_dir/$overlay_base_path/pwm-audio-pi-zero.dtbo" /boot/overlays/pwm-audio-pi-zero.dtbo as_sudo=true
}

__build_port_shortcuts() {
  # Create ports
  dir_rsync '{lib_dir}/gpikit/shortcuts' "$HOME/RetroPie/roms/ports/+GPi/"

  # Don't scrape ports files
  touch "$HOME/RetroPie/roms/ports/+GPi/.skyscraperignore"
}

configure() {
  # Audio settings
  file_cp "{config_dir}/alsa/modprobe.conf" /etc/modprobe.d/alsa-base.conf as_sudo=true
  file_cp "{config_dir}/alsa/asound-mono.conf" /etc/asound-mono.conf as_sudo=true
  file_ln /etc/asound-mono.conf /etc/asound.conf as_sudo=true

  # Fix audio not playing during boot splashscreen
  backup_file /opt/retropie/supplementary/splashscreen/asplashscreen.sh as_sudo=true
  sudo sed -i 's/-o both/-o alsa/g' /opt/retropie/supplementary/splashscreen/asplashscreen.sh
}

restore() {
  restore_file /etc/asound.conf as_sudo=true delete_src=true
  restore_file /etc/asound-mono.conf as_sudo=true delete_src=true
  restore_file /etc/modprobe.d/alsa-base.conf as_sudo=true delete_src=true
  restore_file /opt/retropie/supplementary/splashscreen/asplashscreen.sh as_sudo=true delete_src=true
}

remove() {
  rm -rfv  "$HOME/RetroPie/roms/ports/+GPi"
  restore_file /boot/overlays/dpi24.dtbo as_sudo=true delete_src=true
  restore_file /boot/overlays/pwm-audio-pi-zero.dtbo as_sudo=true delete_src=true
}

setup "${@}"
