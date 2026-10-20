# Shared by capture_screenshots.sh and record_preview.sh.
# Launch arguments for the DEBUG demo store (CardPulse/Models/StoreDemoData.swift).
# `-key value` pairs land in UserDefaults' argument domain for this launch only,
# so they never overwrite the device's real settings.
BUNDLE_ID="com.zqc.TapTrack"
DEMO_ARGS=(-StoreDemo
           -hasCompletedOnboarding YES
           -hasChosenDefaultCurrency YES
           -defaultCurrency SGD
           -displayName Alex
           -mascotColor Gold)

# Set SIMULATOR (a simulator name, UDID or "booted") to launch in the simulator
# instead of on the connected iPhone named by DEVICE.
if [[ -z "${DEVICE:-}" && -z "${SIMULATOR:-}" ]]; then
  echo "Set DEVICE to your iPhone's name or UDID (see: xcrun devicectl list devices)" >&2
  exit 1
fi

# launch_demo <tab 0-3> <Light|Dark>
launch_demo() {
  if [[ -n "${SIMULATOR:-}" ]]; then
    xcrun simctl launch --terminate-running-process "$SIMULATOR" "$BUNDLE_ID" \
      "${DEMO_ARGS[@]}" -StoreTab "$1" -appearance "$2" >/dev/null
  else
    xcrun devicectl device process launch --quiet --terminate-existing --device "$DEVICE" "$BUNDLE_ID" -- \
      "${DEMO_ARGS[@]}" -StoreTab "$1" -appearance "$2"
  fi
}
