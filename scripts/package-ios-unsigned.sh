#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname)" != "Darwin" ]]; then
  echo "An iPhone app must be compiled with Xcode on macOS first."
  exit 1
fi
app="build/ios/iphoneos/Runner.app"
if [[ ! -f "$app/Info.plist" || ! -f "$app/Runner" ]]; then
  echo "Runner.app is missing. Run flutter build ios --release --no-codesign."
  exit 1
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "Unexpected application version."
  exit 1
fi
project_root="$PWD"
staging="$(mktemp -d "${TMPDIR:-/tmp}/twinlock-ipa.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Payload" "$project_root/dist"
ditto "$app" "$staging/Payload/Runner.app"
ipa="$project_root/dist/Twinlock-$version-unsigned.ipa"
ditto -c -k --keepParent "$staging/Payload" "$ipa"
unzip -t "$ipa" >/dev/null
echo "Unsigned IPA created: $ipa"
echo "This file requires Apple signing before it can be installed."
