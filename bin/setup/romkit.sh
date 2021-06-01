#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../common.sh"

install() {
  # Zip
  sudo apt install -y zip

  # XML processing
  sudo apt install -y python3-lxml

  # TorrentZip
  if [ ! `command -v trrntzip` ]; then
    mkdir $tmp_dir/trrntzip
    git clone --depth 1 https://github.com/hydrogen18/trrntzip.git $tmp_dir/trrntzip
    pushd $tmp_dir/trrntzip
    ./autogen.sh
    ./configure
    make
    sudo make install
    popd
    rm -rf $tmp_dir/trrntzip
  else
    echo 'Already installed trrntzip'
  fi

  # CHDMan
  sudo apt install -y mame-tools
}

uninstall() {
  sudo apt remove -y mame-tools python3-lxml zip
  sudo rm /usr/local/bin/trrntzip
}

"${@}"
