#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DART_DEFINES="$("$ROOT_DIR/scripts/dart_defines.sh")"

if [[ -f "$ROOT_DIR/.env" ]]; then
  echo "Usando credenciales de .env"
else
  echo "Sin .env — modo local (copiá .env.example a .env para Supabase)"
fi

echo "Dispositivos Android conectados:"
flutter devices | rg "android" || true
echo

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(flutter devices --machine | python3 - <<'PY'
import json, sys
devices = json.load(sys.stdin)
physical = [
    d for d in devices
    if d.get("platform") == "android" and not d.get("emulator", False)
]
if not physical:
    print("")
else:
    print(physical[0]["id"])
PY
)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No hay celular/tablet Android conectado."
  echo
  echo "1. Activá Opciones de desarrollador → Depuración USB en el dispositivo"
  echo "2. Conectá el cable USB y aceptá 'Confiar en esta computadora'"
  echo "3. Volvé a ejecutar: ./scripts/run_android_device.sh"
  echo
  echo "Para emulador Android:"
  echo "  flutter run -d emulator-5554 --release \$(scripts/dart_defines.sh)"
  exit 1
fi

echo "Ejecutando en dispositivo: $DEVICE_ID (modo release)"
# shellcheck disable=SC2086
flutter run -d "$DEVICE_ID" --release $DART_DEFINES
