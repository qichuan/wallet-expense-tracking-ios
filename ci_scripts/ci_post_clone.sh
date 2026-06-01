#!/bin/sh

# Escape immediately if any command fails
set -e

# Recreate the file from Xcode Cloud Environment Variable
if [ -n "$GOOGLE_SERVICE_BASE64" ]; then
    echo "Decoding GoogleService-Info.plist..."
    echo "$GOOGLE_SERVICE_BASE64" | base64 --decode > "$CI_PRIMARY_REPOSITORY_PATH/CardPulse/GoogleService-Info.plist"
else
    echo "Error: GOOGLE_SERVICE_BASE64 variable is not set."
    exit 1
fi
