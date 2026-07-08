#!/usr/bin/env bash
# Build ChibiNative Release .app (and optional zip for distribution).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED_DATA_PATH:-$ROOT/build}"
CONFIG="${CONFIGURATION:-Release}"
SCHEME="ChibiNative"
PRODUCTS="$DERIVED/Build/Products/$CONFIG"
APP="$PRODUCTS/ChibiNative.app"
DIST="$ROOT/dist"

cd "$ROOT"

if [[ -x "$ROOT/scripts/generate-app-icon.sh" ]]; then
  echo "→ Generating cat app icon…"
  "$ROOT/scripts/generate-app-icon.sh"
fi

echo "→ Building $SCHEME ($CONFIG)…"
xcodebuild \
  -project ChibiNative.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: expected app at $APP" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist")"
ZIP_NAME="ChibiNative-${VERSION}-build${BUILD}-macOS.zip"

mkdir -p "$DIST"
ditto -c -k --keepParent "$APP" "$DIST/$ZIP_NAME"

echo ""
echo "✓ App:  $APP"
echo "✓ Zip:  $DIST/$ZIP_NAME"
echo "  Install: ./scripts/install.sh"
