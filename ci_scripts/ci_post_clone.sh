#!/local/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Decoding GoogleService-Info.plist..."

# Decode the environment variable back into a plist file
echo "$GOOGLE_SERVICE_BASE64" | base64 --decode > ../GoogleService-Info.plist

echo "GoogleService-Info.plist successfully generated!"
