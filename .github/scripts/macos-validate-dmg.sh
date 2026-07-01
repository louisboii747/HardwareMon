#!/bin/bash

set -euo pipefail

DMG_PATH=${1:?Usage: macos-validate-dmg.sh DMG_PATH SIGNED_MODE}
SIGNED_MODE=${2:?SIGNED_MODE must be true or false}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MOUNT_POINT=$(mktemp -d)

cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  rmdir "$MOUNT_POINT" >/dev/null 2>&1 || true
}
trap cleanup EXIT

hdiutil verify "$DMG_PATH"

if [[ "$SIGNED_MODE" == "true" ]]; then
  codesign --verify --strict --verbose=4 "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$DMG_PATH"
fi

hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_POINT"
[[ -L "$MOUNT_POINT/Applications" ]] || {
  echo "DMG is missing the Applications shortcut" >&2
  exit 1
}
[[ "$(readlink "$MOUNT_POINT/Applications")" == "/Applications" ]] || {
  echo "DMG Applications shortcut has the wrong target" >&2
  exit 1
}

"$SCRIPT_DIR/macos-validate-app.sh" \
  "$MOUNT_POINT/HardwareMon.app" \
  "$SIGNED_MODE"

