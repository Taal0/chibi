#!/usr/bin/env bash
# Install or update Chibi in /Applications/Chibi.app.
# Removes duplicate Chibi/ChibiNative installs and optionally relaunches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXEC_NAME="ChibiNative"
BUNDLE_ID="com.talo.ChibiNative"
INSTALL_NAME="Chibi"
INSTALL_PATH="/Applications/${INSTALL_NAME}.app"
RELAUNCH="${RELAUNCH:-1}"

LEGACY_NAMES=(Chibi ChibiNative "Chibi 2" "Chibi 3")

usage() {
  cat <<EOF
Usage: $(basename "$0") [path/to/ChibiNative.app]

Install Chibi to $INSTALL_PATH (replace existing duplicates).

If no path is given, uses Release build:
  $ROOT/build/Build/Products/Release/ChibiNative.app

Env:
  RELAUNCH=0   skip opening the app after install

Examples:
  ./scripts/build-release.sh && ./scripts/install.sh
  ./scripts/install.sh dist/ChibiNative-1.0-build1-macOS.zip
EOF
}

SOURCE="${1:-}"

if [[ "${SOURCE:-}" == "-h" || "${SOURCE:-}" == "--help" ]]; then
  usage
  exit 0
fi

resolve_source() {
  if [[ -z "$SOURCE" ]]; then
    SOURCE="$ROOT/build/Build/Products/Release/ChibiNative.app"
  fi

  if [[ -f "$SOURCE" && "${SOURCE##*.}" == "zip" ]]; then
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    ditto -x -k "$SOURCE" "$tmp"
    if [[ -d "$tmp/ChibiNative.app" ]]; then
      SOURCE="$tmp/ChibiNative.app"
    elif [[ -d "$tmp/Chibi.app" ]]; then
      SOURCE="$tmp/Chibi.app"
    else
      SOURCE="$(find "$tmp" -maxdepth 1 -name '*.app' -print -quit)"
    fi
  fi

  if [[ ! -d "$SOURCE" ]]; then
    echo "error: app not found: $SOURCE" >&2
    echo "Run ./scripts/build-release.sh first, or pass a .app / .zip path." >&2
    exit 1
  fi
}

quit_running() {
  if pgrep -x "$EXEC_NAME" >/dev/null 2>&1; then
    echo "→ Quitting running Chibi…"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
    pkill -x "$EXEC_NAME" 2>/dev/null || true
    for _ in {1..10}; do
      pgrep -x "$EXEC_NAME" >/dev/null 2>&1 || break
      sleep 0.3
    done
    if pgrep -x "$EXEC_NAME" >/dev/null 2>&1; then
      echo "error: Chibi still running; quit from menu bar and retry." >&2
      exit 1
    fi
  fi
}

remove_app() {
  local path="$1"
  if [[ -d "$path" ]]; then
    echo "→ Removing $path"
    rm -rf "$path"
  fi
}

cleanup_duplicates() {
  local dir name path
  for dir in /Applications "$HOME/Applications"; do
    [[ -d "$dir" ]] || continue
    for name in "${LEGACY_NAMES[@]}"; do
      path="$dir/${name}.app"
      if [[ "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")" != "$INSTALL_PATH" ]]; then
        remove_app "$path"
      fi
    done
  done

  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    case "$app" in
      /Applications/*|"${HOME}/Applications"/*)
        if [[ "$app" != "$INSTALL_PATH" ]]; then
          remove_app "$app"
        fi
        ;;
    esac
  done < <(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null || true)
}

install_app() {
  echo "→ Installing to ${INSTALL_PATH}..."
  remove_app "$INSTALL_PATH"
  ditto "$SOURCE" "$INSTALL_PATH"
  xattr -cr "$INSTALL_PATH" 2>/dev/null || true
}

resolve_source
quit_running
cleanup_duplicates
install_app

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$INSTALL_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$INSTALL_PATH/Contents/Info.plist")"
echo "✓ Installed Chibi $VERSION (build $BUILD) → $INSTALL_PATH"

if [[ "$RELAUNCH" == "1" ]]; then
  open "$INSTALL_PATH"
fi
