#!/bin/bash

system='arcade'
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
. "$dir/../../system-common.sh"

setup_module_id='systems/arcade/mame-hiscores'
setup_module_desc='Hiscore support for MAME'

# The following emulators have their hiscores installed automatically by RetroPie:
# * advmame (/opt/retropie/emulators/advmame-joy/share/advance/hiscore.dat)
# * lr-mame2003 ($HOME/RetroPie/BIOS/mame2003/hiscore.dat)
# * lr-mame2003-plus ($HOME/RetroPie/BIOS/mame2003-plus/hiscore.dat)
# * lr-fbneo ($HOME/RetroPie/BIOS/fbneo/hiscore.dat)
# 
# The following emulators have their hiscores installed in the plugins directory:
# * lr-mame2016 ($HOME/RetroPie/BIOS/mame2016/plugins/hiscore/hiscore.dat)
# * lr-mame0222 ($HOME/RetroPie/BIOS/mame0222/plugins/hiscore/hiscore.dat)
# * lr-mame0244 ($HOME/RetroPie/BIOS/mame0244/plugins/hiscore/hiscore.dat)
build() {
  __build_mame2010
  __build_mame2015
}

__build_mame2010() {
  if has_emulator 'lr-mame2010'; then
    download 'https://github.com/libretro/mame2010-libretro/raw/master/metadata/hiscore.dat' "$HOME/RetroPie/BIOS/mame2010/hiscore.dat"
  fi
}

__build_mame2015() {
  if has_emulator 'lr-mame2015'; then
    download 'https://github.com/libretro/mame2015-libretro/raw/master/metadata/hiscore.dat' "$HOME/RetroPie/BIOS/mame2015/hiscore.dat"
  fi
}

configure() {
  if has_emulator 'lr-mame0222'; then
    __configure_mame 0222
  fi

  if has_emulator 'lr-mame0244'; then
    __configure_mame 0244
  fi
}

__configure_mame() {
  local version=$1

  local hiscore_path=$(first_path "{system_config_dir}/mame$version/hiscore.ini" || first_path '{system_config_dir}/mame/hiscore.ini')
  file_cp "$hiscore_path" "$HOME/RetroPie/BIOS/mame$version/ini/hiscore.ini" backup=false
}

restore() {
  rm -fv \
    "$HOME/RetroPie/BIOS/mame0222/ini/hiscore.ini" \
    "$HOME/RetroPie/BIOS/mame0244/ini/hiscore.ini"
}

remove() {
  rm -fv \
    "$HOME/RetroPie/BIOS/mame2010/hiscore.dat" \
    "$HOME/RetroPie/BIOS/mame2015/hiscore.dat"
}

setup "${@}"
