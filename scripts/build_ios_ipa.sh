#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

METHOD="${1:-appstore}"
EXPORT_PLIST="$ROOT_DIR/ios/ExportOptions-${METHOD}.plist"
DART_DEFINES="$("$ROOT_DIR/scripts/dart_defines.sh")"

if [[ ! -f "$EXPORT_PLIST" ]]; then
  echo "Método inválido: $METHOD"
  echo "Usá: appstore (TestFlight) | development | adhoc"
  exit 1
fi

if [[ -f "$ROOT_DIR/.env" ]]; then
  echo "Compilando IPA ($METHOD) con credenciales de .env..."
else
  echo "Compilando IPA ($METHOD) sin .env (modo local)..."
fi

# shellcheck disable=SC2086
flutter build ipa --export-options-plist="$EXPORT_PLIST" $DART_DEFINES

echo
echo "IPA generado en: build/ios/ipa/"
ls -lh build/ios/ipa/*.ipa
