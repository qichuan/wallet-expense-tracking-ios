#!/usr/bin/env bash
# Records the screen of a connected iPhone running the demo store, for an app preview.
#
#   DEVICE="My iPhone" appstore/record_preview.sh [seconds]
#
# Saves appstore/app_preview/raw-preview.mp4. Starts on Today in light mode, then records
# while you drive the app. Suggested path (about 6s each, matching the caption banners
# in make_preview.sh):
#   1. Today: let the mascot bounce, scroll to Recent taps.
#   2. Cards: scroll the goal tiles.
#   3. Recap: switch Week then Month, scroll to "Where it went".
#   4. Me: scroll the stats, calendar and badges.
# Move slowly and pause on each screen; previews play muted, so the UI has to read on its own.
set -euo pipefail
cd "$(dirname "$0")"
source ./demo_launch_args.sh

SECONDS_TO_RECORD="${1:-28}"
OUT="./app_preview"
mkdir -p "$OUT"

launch_demo 0 Light
sleep 3
echo "Recording ${SECONDS_TO_RECORD}s, start driving the app now..."
xcrun devicectl device capture screen-record --device "$DEVICE" \
  --duration "$SECONDS_TO_RECORD" --destination "$OUT/raw-preview.mp4"
echo "Saved appstore/app_preview/raw-preview.mp4, next: appstore/make_preview.sh"
