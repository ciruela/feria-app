#!/usr/bin/env bash
# Usa credenciales de staging o prod para desarrollo local.
#
# Uso:
#   ./scripts/use_env.sh staging   # copia .env.staging → .env
#   ./scripts/use_env.sh prod      # copia .env.prod → .env (si existe)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:?Falta entorno: staging | prod}"

case "$TARGET" in
  staging)
    SRC="$ROOT_DIR/.env.staging"
    ;;
  prod)
    SRC="$ROOT_DIR/.env.prod"
    if [[ ! -f "$SRC" ]]; then
      SRC="$ROOT_DIR/.env"
      echo "Aviso: .env.prod no existe; no se cambió nada."
      exit 0
    fi
    ;;
  *)
    echo "Entorno inválido: $TARGET (staging | prod)"
    exit 1
    ;;
esac

if [[ ! -f "$SRC" ]]; then
  echo "Error: no existe $SRC"
  echo "Copiá .env.staging.example → .env.staging y completá las keys."
  exit 1
fi

cp "$SRC" "$ROOT_DIR/.env"
echo "OK: .env apunta a $TARGET ($SRC)"
