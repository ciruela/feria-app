#!/usr/bin/env bash
# Lee .env y devuelve --dart-define flags para Flutter.
# Uso: flutter run $(scripts/dart_defines.sh)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  exit 0
fi

while IFS='=' read -r key value || [[ -n "$key" ]]; do
  key="${key#"${key%%[![:space:]]*}"}"
  key="${key%"${key##*[![:space:]]}"}"
  [[ -z "$key" || "$key" == \#* ]] && continue

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"

  case "$key" in
    SUPABASE_URL|SUPABASE_ANON_KEY|CATALOG_URL|SELLERS_URL)
      printf ' --dart-define=%s=%s' "$key" "$value"
      ;;
  esac
done < "$ENV_FILE"
