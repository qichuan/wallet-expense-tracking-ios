#!/bin/sh
# Exit immediately if a command exits with a non-zero status
set -e

echo "Decoding GoogleService-Info.plist..."

# Decode the environment variable back into a plist file
echo "$GOOGLE_SERVICE_BASE64" | base64 --decode > ../GoogleService-Info.plist

echo "GoogleService-Info.plist successfully generated!"

# Category API config. Both values are gitignored, so Xcode Cloud rebuilds
# Config/Secrets.xcconfig from environment variables. If they are unset the
# file is still written with empty values, and the app falls back to local
# category guessing instead of failing the build.
echo "Writing Config/Secrets.xcconfig..."

mkdir -p ../Config
printf 'CATEGORY_API_BASE_URL = %s\nCATEGORY_API_TOKEN = %s\n' \
  "$CATEGORY_API_BASE_URL" "$CATEGORY_API_TOKEN" > ../Config/Secrets.xcconfig

echo "Config/Secrets.xcconfig successfully generated!"
