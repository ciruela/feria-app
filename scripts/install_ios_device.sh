#!/usr/bin/env bash
# Compila e instala en iPhone/iPad físico CON credenciales de .env (Supabase).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DART_DEFINES="$("$ROOT_DIR/scripts/dart_defines.sh")"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "ERROR: Falta .env — copiá .env.example y completá SUPABASE_URL y SUPABASE_ANON_KEY"
  exit 1
fi

if [[ -z "$DART_DEFINES" ]]; then
  echo "ERROR: .env no tiene SUPABASE_URL / SUPABASE_ANON_KEY"
  exit 1
fi

DEVICE_ID="${1:-00008150-00111C6236D0C01C}"

echo "Compilando release con Supabase desde .env..."
# shellcheck disable=SC2086
flutter build ios --release $DART_DEFINES

echo "Instalando en $DEVICE_ID..."
flutter install -d "$DEVICE_ID"

echo "Listo — la app debería mostrar login de Supabase (no 'sin Supabase')."
