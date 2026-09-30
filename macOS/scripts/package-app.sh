#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$MACOS_DIR/.build"
DIST_DIR="$MACOS_DIR/dist"
APP_DIR="$DIST_DIR/Guitar Tools.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_BIN_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build \
  --package-path "$MACOS_DIR" \
  -c release

rm -rf "$APP_DIR"
mkdir -p \
  "$MACOS_BIN_DIR" \
  "$RESOURCES_DIR"

cp \
  "$BUILD_DIR/release/GuitarToolsMacApp" \
  "$MACOS_BIN_DIR/GuitarToolsMacApp"

cp \
  "$MACOS_DIR/AppResources/Info.plist" \
  "$CONTENTS_DIR/Info.plist"

if [[ -n "${GETSONGBPM_API_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy \
    -c "Add :GetSongBPMAPIKey string ${GETSONGBPM_API_KEY}" \
    "$CONTENTS_DIR/Info.plist"
fi

codesign \
  --force \
  --deep \
  --sign - \
  --entitlements \
  "$MACOS_DIR/AppResources/GuitarToolsMac.entitlements" \
  "$APP_DIR"

echo "Packaged: $APP_DIR"
