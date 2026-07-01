#!/bin/bash

set -euo pipefail

APP_BUNDLE=${1:?Usage: macos-sign-app.sh APP_BUNDLE SIGNING_IDENTITY ENTITLEMENTS}
SIGNING_IDENTITY=${2:?Missing signing identity (use - for ad-hoc signing)}
ENTITLEMENTS=${3:?Missing entitlements file}

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle does not exist: $APP_BUNDLE" >&2
  exit 1
fi

# Remove quarantine/resource-fork detritus from build inputs before any seal is
# created. The only later in-bundle change is Apple's notarization staple.
xattr -cr "$APP_BUNDLE"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  timestamp_args=(--timestamp=none)
  echo "Applying an ad-hoc signature for CI integrity validation."
else
  timestamp_args=(--timestamp)
  echo "Signing with Developer ID identity: $SIGNING_IDENTITY"
fi

sign_code() {
  codesign \
    --force \
    --options runtime \
    "${timestamp_args[@]}" \
    --sign "$SIGNING_IDENTITY" \
    "$1"
}

# PyInstaller helpers, dylibs, Flutter binaries, and plug-in binaries must be
# signed before their containing framework/bundle and before the outer app.
while IFS= read -r -d '' candidate; do
  if file -b "$candidate" | grep -q 'Mach-O'; then
    sign_code "$candidate"
  fi
done < <(find "$APP_BUNDLE/Contents" -type f -print0)

# Sign nested code bundles inside-out. `find -depth` guarantees children are
# processed before a containing bundle.
while IFS= read -r -d '' nested_bundle; do
  sign_code "$nested_bundle"
done < <(
  find "$APP_BUNDLE/Contents" -depth -type d \
    \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \
       -o -name '*.appex' -o -name '*.bundle' \) -print0
)

codesign \
  --force \
  --options runtime \
  "${timestamp_args[@]}" \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_BUNDLE"
