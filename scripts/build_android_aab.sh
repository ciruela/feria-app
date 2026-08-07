#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

KEY_PROPS="$ROOT_DIR/android/key.properties"
DART_DEFINES="$("$ROOT_DIR/scripts/dart_defines.sh")"

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "Falta android/key.properties (firma de release)."
  echo "Ejecutá primero: ./scripts/setup_android_keystore.sh"
  exit 1
fi

if [[ -f "$ROOT_DIR/.env" ]]; then
  echo "Compilando AAB con credenciales de .env..."
else
  echo "Compilando AAB sin .env (modo local)..."
fi

# shellcheck disable=SC2086
flutter build appbundle --release $DART_DEFINES

echo
echo "AAB generado en: build/app/outputs/bundle/release/"
ls -lh build/app/outputs/bundle/release/*.aab
