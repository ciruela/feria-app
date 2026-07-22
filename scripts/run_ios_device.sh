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

echo "Dispositivos iOS conectados:"
flutter devices | rg "ios" || true
echo

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(flutter devices --machine | python3 - <<'PY'
import json, sys
devices = json.load(sys.stdin)
physical = [
    d for d in devices
    if d.get("platform") == "ios" and not d.get("emulator", False)
]
if not physical:
    print("")
else:
    print(physical[0]["id"])
PY
)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "No hay iPhone/iPad físico conectado."
  echo "Conectá el cable, desbloqueá el dispositivo y tocá Confiar en esta Mac."
  echo
  echo "Para simulador iOS 17.5 (desarrollo):"
  echo "  flutter run -d \"iPhone 15 Pro\" $(scripts/dart_defines.sh)"
  exit 1
fi

echo "Ejecutando en dispositivo: $DEVICE_ID (modo release)"
# shellcheck disable=SC2086
flutter run -d "$DEVICE_ID" --release $DART_DEFINES
