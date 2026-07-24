#!/usr/bin/env bash
# Apple exige compilar con Xcode 26+ / iOS SDK 26+ para subir a App Store Connect
# (https://developer.apple.com/news/upcoming-requirements/?id=02032026a)
set -euo pipefail

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild no está instalado. Instalá Xcode 26 desde la Mac App Store."
  exit 1
fi

XCODE_VERSION="$(xcodebuild -version | head -1)"
MAJOR="${XCODE_VERSION#Xcode }"
MAJOR="${MAJOR%%.*}"

if [[ "$MAJOR" -lt 26 ]]; then
  echo "Error: $XCODE_VERSION detectado."
  echo "Apple exige Xcode 26 o posterior para subir builds a App Store Connect."
  echo
  echo "Instalá Xcode 26 y seleccionalo:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo
  xcodebuild -showsdks 2>/dev/null | grep -E 'iphoneos|iOS' || true
  exit 1
fi

SDK_LINE="$(xcodebuild -showsdks 2>/dev/null | grep -E 'iphoneos' | tail -1 || true)"
echo "OK: $XCODE_VERSION — $SDK_LINE"
