#!/usr/bin/env bash
# Launches the demo store on each tab of a connected iPhone, captures it, then
# frames the captures with StoreArt.swift.
#
#   DEVICE="My iPhone" appstore/capture_screenshots.sh
#
# Writes raw captures to appstore/original_screenshots/ and framed screenshots to
# appstore/appstore_screenshots/iPhone <size> (<w>x<h>)/, replacing files of the same name.
#
# Install a Debug build from Xcode first. Unlock the phone, and turn on Focus/Do Not
# Disturb so no banners land in the shots.
set -euo pipefail
cd "$(dirname "$0")"
source ./demo_launch_args.sh

RAW="./original_screenshots"
OUT="./appstore_screenshots"
mkdir -p "$RAW"

capture() { # <tab> <appearance> <file>
  launch_demo "$1" "$2"
  sleep 4 # let the mascot settle and charts animate in
  xcrun devicectl device capture screenshot --quiet --device "$DEVICE" --destination "$RAW/$3"
  echo "captured $3"
}

capture 0 Light 1-today.png
capture 1 Light 2-cards.png
capture 2 Light 3-recap.png
capture 3 Light 4-me.png
capture 0 Dark  5-today-dark.png

swift StoreArt.swift screenshots "$RAW" "$OUT"
echo "Done: appstore/appstore_screenshots/"
