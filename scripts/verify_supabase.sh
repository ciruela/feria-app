#!/usr/bin/env bash
# Verifica conexión a Supabase y tablas requeridas.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No existe .env"
  echo "Ejecutá: ./scripts/setup_supabase_env.sh"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Error: .env incompleto (SUPABASE_URL y SUPABASE_ANON_KEY)"
  exit 1
fi

BASE="${SUPABASE_URL%/}"
HDR=(-H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY")

echo "Conectando a $BASE ..."
echo

check_table() {
  local table="$1"
  local code
  code=$(curl -s -o /tmp/supabase_check.json -w "%{http_code}" \
    "$BASE/rest/v1/$table?select=*&limit=1" "${HDR[@]}")

  if [[ "$code" == "200" ]]; then
    echo "  ✓ $table"
    return 0
  fi

  echo "  ✗ $table (HTTP $code)"
  if [[ -f /tmp/supabase_check.json ]]; then
    cat /tmp/supabase_check.json
    echo
  fi
  return 1
}

ok=true
check_table productos || ok=false
check_table vendedores || ok=false
check_table ventas || ok=false
check_table app_config || ok=false

echo
if $ok; then
  vendedores=$(curl -s "$BASE/rest/v1/vendedores?select=id" "${HDR[@]}" -H "Prefer: count=exact" -I \
    | grep -i content-range | sed 's/.*\///' | tr -d '\r\n')
  config=$(curl -s "$BASE/rest/v1/app_config?id=eq.global&select=exchange_rate_ars" "${HDR[@]}")
  echo "Vendedores en nube: ${vendedores:-?}"
  echo "Tipo de cambio global: $config"
  echo
  echo "✓ Supabase listo. Corré la app con:"
  echo "  ./scripts/run_ios_device.sh"
  echo
  echo "En Admin → Publicar catálogo a Supabase (carga inicial de productos)"
else
  echo "Faltan tablas. Ejecutá supabase/bootstrap.sql en el SQL Editor del Dashboard."
  exit 1
fi
