#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  # Check out
  rm -rf "$tmp_dir/dispmanx_vnc"
  git clone --depth 1 https://github.com/patrikolausson/dispmanx_vnc "$tmp_dir/dispmanx_vnc"
  pushd "$tmp_dir/dispmanx_vnc"
  local version=$(git rev-parse HEAD)

  if [ ! -f '/etc/dispmanx_vncserver.version' ] || [ "$version" != "$(cat /etc/dispmanx_vncserver.version)" ]; then
    # Install dependencies
    sudo apt install -y libvncserver-dev libconfig++-dev

    # Apply patches
    patch -p1 < "$config_dir/vnc/0001-fix-keyboard.patch"

    # Compile
    make

    # Copy to system
    sudo systemctl stop dispmanx_vncserver || true
    sudo cp dispmanx_vncserver /usr/bin
    sudo chmod +x /usr/bin/dispmanx_vncserver
    file_cp "$config_dir/vnc/dispmanx_vncserver.conf" /etc/dispmanx_vncserver.conf as_sudo=true

    # Install service
    file_cp "$config_dir/vnc/dispmanx_vncserver.service" /etc/systemd/system/dispmanx_vncserver.service envsubst=false as_sudo=true
    sudo systemctl daemon-reload
    sudo systemctl enable dispmanx_vncserver
    sudo systemctl start dispmanx_vncserver
    echo "$version" | sudo tee /etc/dispmanx_vncserver.version
  else
    echo "dispmanx_vnc already at latest version ($version)"
  fi

  # Clean up
  popd
  rm -rf $tmp_dir/dispmanx_vnc
}

uninstall() {
  sudo systemctl stop dispmanx_vncserver || true
  sudo systemctl disable dispmanx_vncserver || true
  sudo rm -f /etc/dispmanx_vncserver.version
  sudo rm -f /etc/systemd/system/dispmanx_vncserver.service
  sudo rm -f /etc/dispmanx_vncserver.conf
  sudo rm -f /usr/bin/dispmanx_vncserver
}

"${@}"
