#!/usr/bin/env bash
# Build AppIcon.icns + menu-bar tray.png from calico-idle.apng (first frame).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_APNG="$ROOT/ChibiNative/Resources/theme/calico/assets/calico-idle.apng"
OUT_ICNS="$ROOT/ChibiNative/Resources/AppIcon.icns"
OUT_TRAY="$ROOT/ChibiNative/Resources/tray.png"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -f "$SRC_APNG" ]]; then
  echo "error: missing $SRC_APNG" >&2
  exit 1
fi

echo "→ Extracting idle frame…"
sips -s format png "$SRC_APNG" --out "$WORK/cat.png" >/dev/null
sips --padToHeightWidth 280 280 "$WORK/cat.png" --out "$WORK/square.png" >/dev/null
sips -z 1024 1024 "$WORK/square.png" --out "$WORK/icon_1024.png" >/dev/null

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

make_icon() {
  local size=$1
  local name=$2
  sips -z "$size" "$size" "$WORK/icon_1024.png" --out "$ICONSET/$name" >/dev/null
}

make_icon 16  icon_16x16.png
make_icon 32  icon_16x16@2x.png
make_icon 32  icon_32x32.png
make_icon 64  icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
cp "$WORK/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

echo "→ Building AppIcon.icns…"
iconutil -c icns "$ICONSET" -o "$OUT_ICNS"

echo "→ Building tray.png…"
sips -z 128 128 "$WORK/square.png" --out "$OUT_TRAY" >/dev/null

echo "✓ $OUT_ICNS"
echo "✓ $OUT_TRAY"
