#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# The maximum amount of time that we'll show the launch image
MAX_LOADING_TIME=10

clear_screen() {
  dd if=/dev/zero of=/dev/fb0 &>/dev/null
}

# Watches for interrupts to the launching screen
watch_screen() {
  while true; do
    # User has opened runcommand dialog or we're no longer running the game, abort
    if pgrep dialog || ! kill -0 $PPID; then
      break
    fi

    # Maximum time reached for showing the launching screen
    if [ $SECONDS -ge $MAX_LOADING_TIME ]; then
      clear_screen
      break
    fi

    sleep 1
  done
}

show_launching_screen() {
  local system="$1"
  local launch_image="/opt/retropie/configs/$system/launching-extended.png"

  if [ -f "$launch_image" ]; then
    # Change tty to graphics mode
    python "$dir/runcommand-tty.py" /dev/tty graphics

    # Show launching screen.  We use ffmpeg instead of fbi since it will
    # draw to the screen and then exit, leaving the image there.  fbi has
    # a lot else going on with responding to keyboard inputs and changing
    # the virtual terminal when exiting, causing emulators to fail.
    ffmpeg -i /opt/retropie/configs/$system/launching-extended.png -s $(< /sys/class/graphics/fb0/virtual_size tr , x) -f fbdev -pix_fmt rgb565le -y /dev/fb0

    # Monitor launching screen
    watch_screen &
  fi
}

launch_manualkit() {
  local system=$1
  local emulator=$2
  local rom_path=$3

  # Check to see if a manual exists
  local rom_filename=$(basename "$rom_path")
  local rom_name=${rom_filename%.*}
  local manual_path="$HOME/.emulationstation/downloaded_media/$system/manuals/$rom_name.pdf"

  # Start up manualkit
  sudo python3 /opt/retropie/supplementary/manualkit/cli.py "$manual_path" /opt/retropie/configs/all/manualkit.conf &
}

# This script shows the launch image in the background while allowing
# RetroPie to star the game in the foreground.  It improves the load time
# by a few seconds.
# 
# It also proactively clears the screen so that when you exit the game,
# the transition is smooth from game -> black screen -> emulation station.
# Without this, there's a hard transition from game -> launch image ->
# black screen -> emulation station, which is a bit jarring.
clear_screen
show_launching_screen "${@}" </dev/null &>/dev/null
launch_manualkit "${@}" </dev/null &>/dev/null
