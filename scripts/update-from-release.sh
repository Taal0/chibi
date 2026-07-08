#!/usr/bin/env bash
# Download latest (or specific) GitHub release and install to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${CHIBI_GH_REPO:-Taal0/chibi}"
TAG="${1:-latest}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) required. brew install gh && gh auth login" >&2
  exit 1
fi

echo "→ Downloading release ($TAG) from ${REPO}..."
if [[ "$TAG" == "latest" ]]; then
  gh release download --repo "$REPO" --dir "$TMP" --pattern 'ChibiNative-*.zip'
else
  gh release download "$TAG" --repo "$REPO" --dir "$TMP" --pattern 'ChibiNative-*.zip'
fi

ZIP="$(find "$TMP" -name 'ChibiNative-*.zip' -print -quit)"
if [[ -z "$ZIP" ]]; then
  echo "error: no ChibiNative zip in release" >&2
  exit 1
fi

exec "$ROOT/scripts/install.sh" "$ZIP"
