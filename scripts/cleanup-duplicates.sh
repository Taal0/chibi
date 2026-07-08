#!/usr/bin/env bash
# Remove duplicate Chibi installs from Applications (keeps /Applications/Chibi.app if present).
set -euo pipefail

BUNDLE_ID="com.talo.ChibiNative"
KEEP="${1:-/Applications/Chibi.app}"
LEGACY_NAMES=(Chibi ChibiNative "Chibi 2" "Chibi 3")

remove_app() {
  local path="$1"
  if [[ -d "$path" && "$path" != "$KEEP" ]]; then
    echo "→ Removing $path"
    rm -rf "$path"
  fi
}

echo "Keeping: $KEEP"
echo "→ Scanning Applications…"

for dir in /Applications "$HOME/Applications"; do
  [[ -d "$dir" ]] || continue
  for name in "${LEGACY_NAMES[@]}"; do
    remove_app "$dir/${name}.app"
  done
done

while IFS= read -r app; do
  [[ -z "$app" ]] && continue
  case "$app" in
    /Applications/*|"${HOME}/Applications"/*) remove_app "$app" ;;
  esac
done < <(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null || true)

echo "✓ Cleanup done"
