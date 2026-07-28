#!/usr/bin/env bash
# Levanta la app en Chrome (Flutter Web) con credenciales de .env.
#
# Uso:
#   ./scripts/run_web.sh
#   ./scripts/run_web.sh 8080   # puerto custom
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PORT="${1:-7357}"
DART_DEFINES="$("$ROOT_DIR/scripts/dart_defines.sh")"

if [[ -f "$ROOT_DIR/.env" ]]; then
  echo "Usando credenciales de .env"
else
  echo "Sin .env — modo local (copiá .env.example a .env para Supabase)"
fi

echo "Abriendo http://localhost:$PORT"
# shellcheck disable=SC2086
flutter run -d chrome --web-port="$PORT" $DART_DEFINES
