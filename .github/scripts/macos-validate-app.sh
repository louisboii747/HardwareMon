#!/bin/bash

set -euo pipefail

APP_BUNDLE=${1:?Usage: macos-validate-app.sh APP_BUNDLE GATEKEEPER_REQUIRED}
GATEKEEPER_REQUIRED=${2:?GATEKEEPER_REQUIRED must be true or false}
EXPECTED_BUNDLE_ID=${EXPECTED_BUNDLE_ID:-com.hardwaremon.HardwareMon}

fail() {
  echo "macOS bundle validation failed: $*" >&2
  exit 1
}

[[ -d "$APP_BUNDLE/Contents" ]] || fail "missing Contents directory"
[[ -d "$APP_BUNDLE/Contents/MacOS" ]] || fail "missing Contents/MacOS"
[[ -d "$APP_BUNDLE/Contents/Frameworks" ]] || fail "missing Contents/Frameworks"
[[ -f "$APP_BUNDLE/Contents/Info.plist" ]] || fail "missing Info.plist"
LOCAL_NOTIFIER_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/local_notifier.framework"
[[ -d "$LOCAL_NOTIFIER_FRAMEWORK" ]] || \
  fail "embedded local_notifier.framework is missing"

plutil -lint "$APP_BUNDLE/Contents/Info.plist"

BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$APP_BUNDLE/Contents/Info.plist")
BUNDLE_TYPE=$(plutil -extract CFBundlePackageType raw "$APP_BUNDLE/Contents/Info.plist")
EXECUTABLE_NAME=$(plutil -extract CFBundleExecutable raw "$APP_BUNDLE/Contents/Info.plist")
ICON_NAME=$(plutil -extract CFBundleIconFile raw "$APP_BUNDLE/Contents/Info.plist")

[[ "$BUNDLE_ID" == "$EXPECTED_BUNDLE_ID" ]] || \
  fail "expected bundle id $EXPECTED_BUNDLE_ID, found $BUNDLE_ID"
[[ "$BUNDLE_TYPE" == "APPL" ]] || fail "CFBundlePackageType is not APPL"
[[ -n "$EXECUTABLE_NAME" ]] || fail "CFBundleExecutable is empty"
[[ -x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" ]] || \
  fail "main executable is missing or not executable"
BACKEND_APP="$APP_BUNDLE/Contents/Helpers/HardwareMonBackend.app"
BACKEND_EXECUTABLE="$BACKEND_APP/Contents/MacOS/backend"
BACKEND_ENTRYPOINT="$APP_BUNDLE/Contents/Helpers/backend"
[[ -d "$BACKEND_APP" ]] || fail "telemetry helper app bundle is missing"
[[ -f "$BACKEND_APP/Contents/Info.plist" ]] || \
  fail "telemetry helper Info.plist is missing"
plutil -lint "$BACKEND_APP/Contents/Info.plist"
BACKEND_BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw \
  "$BACKEND_APP/Contents/Info.plist")
[[ "$BACKEND_BUNDLE_ID" == "com.hardwaremon.HardwareMon.backend" ]] || \
  fail "telemetry helper has unexpected bundle id $BACKEND_BUNDLE_ID"
[[ -x "$BACKEND_EXECUTABLE" ]] || \
  fail "telemetry helper is missing or not executable"
[[ -x "$BACKEND_ENTRYPOINT" ]] || \
  fail "Contents/Helpers/backend is missing or not executable"
[[ "$(readlink "$BACKEND_ENTRYPOINT")" == \
    "HardwareMonBackend.app/Contents/MacOS/backend" ]] || \
  fail "Contents/Helpers/backend does not target the signed helper executable"
[[ "$ICON_NAME" == "AppIcon" || "$ICON_NAME" == "AppIcon.icns" ]] || \
  fail "CFBundleIconFile does not reference AppIcon"
[[ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]] || \
  fail "compiled AppIcon.icns is missing"

file "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
file "$BACKEND_EXECUTABLE"
file "$BACKEND_ENTRYPOINT"
file -b "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" | grep -q 'Mach-O' || \
  fail "main executable is not Mach-O"
file -b "$BACKEND_EXECUTABLE" | grep -q 'Mach-O' || \
  fail "telemetry helper is not Mach-O"

codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"
codesign -dv --verbose=4 "$APP_BUNDLE"

echo "Verifying the embedded local_notifier framework signature"
codesign --verify --strict --verbose=2 "$LOCAL_NOTIFIER_FRAMEWORK"

echo "Verifying every embedded Mach-O object and code bundle"
while IFS= read -r -d '' candidate; do
  if file -b "$candidate" | grep -q 'Mach-O'; then
    codesign --verify --strict --verbose=2 "$candidate"
    while IFS= read -r dependency; do
      case "$dependency" in
        @*|/System/*|/usr/lib/*) ;;
        *) fail "$candidate links to non-system absolute path $dependency" ;;
      esac
    # Universal Mach-O output contains one non-indented header per architecture.
    # Only indented rows are linked-library entries.
    done < <(otool -L "$candidate" | awk '/^[[:space:]]/ {print $1}')
  fi
done < <(find "$APP_BUNDLE/Contents" -type f -print0)

while IFS= read -r -d '' nested_bundle; do
  codesign --verify --strict --verbose=2 "$nested_bundle"
done < <(
  find "$APP_BUNDLE/Contents" -depth -type d \
    \( -name '*.framework' -o -name '*.app' -o -name '*.xpc' \
       -o -name '*.appex' -o -name '*.bundle' \) -print0
)

echo "Linked libraries for the application executable"
otool -L "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
echo "Linked libraries for the telemetry helper"
otool -L "$BACKEND_EXECUTABLE"

echo "Extended attributes (empty output is expected before distribution)"
xattr -lr "$APP_BUNDLE" || true

if [[ "$GATEKEEPER_REQUIRED" == "true" ]]; then
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
else
  echo "Gatekeeper assessment is diagnostic for the current ad-hoc-signed build."
  spctl --assess --type execute --verbose=4 "$APP_BUNDLE" || true
fi
