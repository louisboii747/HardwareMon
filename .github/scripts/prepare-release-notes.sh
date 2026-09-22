#!/usr/bin/env bash

set -euo pipefail

output_path="${1:?Usage: prepare-release-notes.sh OUTPUT_PATH RELEASE_TAG}"
release_tag="${2:?Usage: prepare-release-notes.sh OUTPUT_PATH RELEASE_TAG}"
repository="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"
version="${release_tag#v}"
generated_notes="$(mktemp)"

trap 'rm -f "$generated_notes"' EXIT

# Fetch a fresh body instead of asking the release action to generate notes.
# action-gh-release appends generated notes when an existing release is updated,
# which duplicates the changelog when platform workflows finish or are rerun.
gh api \
  --method POST \
  "repos/$repository/releases/generate-notes" \
  -f "tag_name=$release_tag" \
  --jq .body > "$generated_notes"

{
  printf '## Downloads\n\n'
  printf -- '- **Windows:** `%s`\n' "HardwareMon-$release_tag.exe"
  printf -- '- **macOS:** `%s` (Apple silicon only; ad-hoc signed and not notarized)\n' "HardwareMon-macOS-$version.dmg"
  printf -- '- **Debian / Ubuntu:** `hardwaremon.deb`\n'
  printf -- '- **Fedora / RPM-based Linux:** `hardwaremon.rpm`\n'
  printf -- '- **Flatpak:** `hardwaremon.flatpak` (experimental)\n'
  printf -- '- **Android:** `%s`\n' "HardwareMon-Android-$release_tag.apk"
  printf '\nPlatform builds run independently. If an expected file is not listed yet, refresh the release page after the remaining builds finish.\n'
  printf '\n## Security and verification\n\n'
  printf 'Release assets include SHA-256 checksums, build metadata, and GitHub provenance attestations. Desktop builds also include CycloneDX SBOMs. See the [release verification guide](https://github.com/%s/blob/%s/docs/release-verification.md) before installing a manually downloaded package.\n' \
    "$repository" "$release_tag"

  if [[ -s "$generated_notes" ]]; then
    printf '\n'
    cat "$generated_notes"
  fi
} > "$output_path"
