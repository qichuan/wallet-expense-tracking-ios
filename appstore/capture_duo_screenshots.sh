#!/usr/bin/env bash
# Captures the demo store on the iPhone Duo simulator in each pose, then frames the
# captures with StoreArt.swift at the iPhone Duo screenshot sizes.
#
#   SIMULATOR="iPhone Duo" appstore/capture_duo_screenshots.sh
#   POSES="open-landscape open-portrait" SIMULATOR=booted appstore/capture_duo_screenshots.sh
#
# There's no command-line control for the Duo's poses, so the script pauses before each
# pose: set it in Device Hub (open or closed, rotated), then press Return. Poses default
# to all four in StoreArt.swift's `duoPoses`:
#   open-landscape   → 2853×2007   open-portrait   → 2007×2853   (inner display)
#   closed-landscape → 2034×1398   closed-portrait → 1398×2034   (outer display)
#
# Writes raw captures to appstore/original_screenshots/duo/<pose>/ and framed screenshots
# to appstore/appstore_screenshots/iPhone Duo <pose> (<w>x<h>)/, replacing files of the
# same name.
#
# Run a Debug build of the TapTrack scheme on the iPhone Duo simulator from Xcode first,
# so the app with -StoreDemo support is installed.
set -euo pipefail
cd "$(dirname "$0")"
SIMULATOR="${SIMULATOR:-booted}"
source ./demo_launch_args.sh

RAW="./original_screenshots/duo"
OUT="./appstore_screenshots"
read -r -a POSE_LIST <<< "${POSES:-open-landscape open-portrait closed-landscape closed-portrait}"

# Clean 9:41 status bar, restored when the script ends.
xcrun simctl status_bar "$SIMULATOR" override --time "9:41" --dataNetwork wifi --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
trap 'xcrun simctl status_bar "$SIMULATOR" clear' EXIT

capture() { # <dir> <tab> <appearance> <file>
  launch_demo "$2" "$3"
  sleep 4 # let the mascot settle and charts animate in
  xcrun simctl io "$SIMULATOR" screenshot --type=png "$1/$4" >/dev/null
  echo "captured $1/$4"
}

for pose in "${POSE_LIST[@]}"; do
  read -r -p "Set the simulator to ${pose/-/, } in Device Hub, then press Return " _
  dir="$RAW/$pose"
  mkdir -p "$dir"
  capture "$dir" 0 Light 1-today.png
  capture "$dir" 1 Light 2-cards.png
  capture "$dir" 2 Light 3-recap.png
  capture "$dir" 3 Light 4-me.png
  capture "$dir" 0 Dark  5-today-dark.png
done

swift StoreArt.swift duo "$RAW" "$OUT"
echo "Done: appstore/appstore_screenshots/iPhone Duo */"
