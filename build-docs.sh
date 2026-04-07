#!/bin/bash
set -e

# Disable Xcode macro fingerprint validation to prevent spurious build errors
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

# Clean derived data to avoid stale explicit module caches
rm -rf .build

xcodebuild docbuild \
  -project DocB.xcodeproj \
  -scheme DocB \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DISABLE_SWIFTLINT=1

# Find the generated archive for DocB specifically (not third-party dependency archives)
ARCHIVE_PATH=$(find .build -type d -name 'DocB.doccarchive' | head -n 1)

if [ -z "$ARCHIVE_PATH" ]; then
  echo "Error: Could not find .doccarchive file"
  exit 1
fi

echo "Found archive at: $ARCHIVE_PATH"

$(xcrun --find docc) process-archive transform-for-static-hosting \
  "$ARCHIVE_PATH" \
  --output-path ./docs \
  --hosting-base-path /
