#!/usr/bin/env bash
# Launches the demo store on each tab of a connected iPhone, captures it, then
# frames the captures with StoreArt.swift.
#
#   DEVICE="My iPhone" scripts/app-store/capture_screenshots.sh [out dir]
#
# Install a Debug build from Xcode first. Unlock the phone, and turn on Focus/Do Not
# Disturb so no banners land in the shots.
set -euo pipefail
cd "$(dirname "$0")"
source ./demo_launch_args.sh

OUT="${1:-./output}"
RAW="$OUT/raw"
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

swift StoreArt.swift screenshots "$RAW" "$OUT/screenshots"
echo "Done: $OUT/screenshots/{6.9in,6.5in,6.1in}"
