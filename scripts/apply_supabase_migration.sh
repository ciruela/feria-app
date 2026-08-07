#!/usr/bin/env bash
# Aplica un archivo SQL al proyecto Supabase vía Management API.
#
# Requiere: SUPABASE_ACCESS_TOKEN, PROJECT_REF (default ihotjvimurztbhrsiabs)
# Uso: ./scripts/apply_supabase_migration.sh supabase/migrations/042_....sql
set -euo pipefail

FILE="${1:?Falta path al .sql}"
PROJECT_REF="${PROJECT_REF:-ihotjvimurztbhrsiabs}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: falta SUPABASE_ACCESS_TOKEN"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "Error: no existe $FILE"
  exit 1
fi

run_sql() {
  local label="$1"
  local sql="$2"
  local body http
  body="$(jq -n --arg q "$sql" '{query: $q}')"
  echo "→ $label"
  http="$(curl -sS -o /tmp/supabase_sql_out.json -w '%{http_code}' \
    -X POST "https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary "$body")"
  echo "HTTP $http"
  cat /tmp/supabase_sql_out.json
  echo
  if [[ "$http" -lt 200 || "$http" -ge 300 ]]; then
    echo "Falló: $label"
    exit 1
  fi
}

SQL="$(cat "$FILE")"
run_sql "apply $(basename "$FILE")" "$SQL"

BASENAME="$(basename "$FILE" .sql)"
VERSION="${BASENAME%%_*}"
if [[ "$VERSION" =~ ^[0-9]+$ ]]; then
  # Best-effort: registra la versión (no aborta el apply si el schema difiere).
  REG="insert into supabase_migrations.schema_migrations (version) values ('${VERSION}') on conflict do nothing;"
  body="$(jq -n --arg q "$REG" '{query: $q}')"
  echo "→ register version $VERSION (best-effort)"
  curl -sS -o /tmp/supabase_sql_reg.json -w 'HTTP %{http_code}\n' \
    -X POST "https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    --data-binary "$body" || true
  cat /tmp/supabase_sql_reg.json || true
  echo
fi

echo "OK: $FILE"
