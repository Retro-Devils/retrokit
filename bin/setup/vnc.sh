#!/bin/bash

set -ex

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  # Install dependencies
  sudo apt install -y libvncserver-dev libconfig++-dev

  # Compile
  rm -rf $tmp_dir/dispmanx_vnc
  git clone https://github.com/patrikolausson/dispmanx_vnc "$tmp_dir/dispmanx_vnc"
  pushd $tmp_dir/dispmanx_vnc
  make

  # Copy to system
  sudo cp dispmanx_vncserver /usr/bin
  sudo chmod +x /usr/bin/dispmanx_vncserver
  file_cp "$config_dir/vnc/dispmanx_vncserver.conf" /etc/dispmanx_vncserver.conf as_sudo=true

  # Install service
  file_cp "$config_dir/vnc/dispmanx_vncserver.service" /etc/systemd/system/dispmanx_vncserver.service as_sudo=true
  sudo systemctl start dispmanx_vncserver.service
  sudo systemctl enable dispmanx_vncserver.service
  sudo systemctl daemon-reload

  # Clean up
  popd
  rm -rf $tmp_dir/dispmanx_vnc
}

uninstall() {
  sudo systemctl stop dispmanx_vncserver.service || true
  sudo systemctl disable dispmanx_vncserver.service || true
  sudo rm -f /etc/systemd/system/dispmanx_vncserver.service
  sudo rm -f /etc/dispmanx_vncserver.conf
  sudo rm -f /usr/bin/dispmanx_vncserver
}

"${@}"
