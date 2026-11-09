#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:---development}"
case "$mode" in
  --unsigned|--unsigned-ipa|--development|--ad-hoc) ;;
  *) echo "Usage: bash scripts/build-ios.sh [--unsigned|--unsigned-ipa|--development|--ad-hoc]"; exit 64 ;;
esac
if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS builds require macOS and Xcode."
  exit 1
fi
flutter pub get
flutter analyze
flutter test
flutter precache --ios
(cd ios && pod install)
if [[ "$mode" == "--unsigned" || "$mode" == "--unsigned-ipa" ]]; then
  flutter build ios --release --no-codesign
  if [[ "$mode" == "--unsigned-ipa" ]]; then
    bash scripts/package-ios-unsigned.sh
  else
    echo "Unsigned app: build/ios/iphoneos/Runner.app. Sign it with Xcode before installing."
  fi
else
  marker="$(mktemp "${TMPDIR:-/tmp}/twinlock-signing.XXXXXX")"
  trap 'rm -f "$marker"' EXIT
  method=development
  if [[ "$mode" == "--ad-hoc" ]]; then method=ad-hoc; fi
  flutter build ipa --release --export-method "$method"
  produced=0
  for ipa in build/ios/ipa/*.ipa; do
    if [[ -f "$ipa" && "$ipa" -nt "$marker" ]]; then
      unzip -t "$ipa" >/dev/null
      codesign --verify --deep --strict "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
      echo "Signed $method IPA verified: $ipa"
      produced=1
    fi
  done
  if [[ "$produced" != 1 ]]; then
    echo "No new signed IPA was exported. Configure Xcode Team, certificate and the device provisioning profile."
    exit 1
  fi
fi
