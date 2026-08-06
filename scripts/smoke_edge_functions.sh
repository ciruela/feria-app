#!/usr/bin/env bash
# AR-19: smoke post-deploy — cada Edge Function debe existir.
# Auth-required puede devolver 401/403; eso cuenta como "deployada".
# Un 404 del gateway ("Requested function was not found") es falla.
set -euo pipefail

: "${SUPABASE_URL:?Falta SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Falta SUPABASE_ANON_KEY}"

BASE="${SUPABASE_URL%/}/functions/v1"
fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

check() {
  local name="$1"
  local method="$2"
  local path="$3"
  local code
  code=$(curl -sS -o "$tmp" -w "%{http_code}" \
    -X "$method" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Content-Type: application/json" \
    --max-time 20 \
    "${BASE}${path}" || echo "000")

  local body
  body="$(cat "$tmp" 2>/dev/null || true)"
  if [[ "$code" == "000" ]]; then
    echo "FAIL $name -> sin respuesta"
    fail=1
  elif [[ "$body" == *"Requested function was not found"* ]] || \
       [[ "$body" == *"Function not found"* ]]; then
    echo "FAIL $name -> HTTP $code (función no deployada)"
    fail=1
  else
    echo "OK   $name -> HTTP $code"
  fi
}

# POST sin body: 401/400/405 ok.
check platform-metrics POST /platform-metrics
check register-tenant-subdomain POST /register-tenant-subdomain
check invite-team-member POST /invite-team-member
check remove-team-member POST /remove-team-member
check storefront-order POST /storefront-order
check seller-portal-validate POST /seller-portal-validate
# GET público (slug inválido puede ser 404 de negocio; no del gateway).
check storefront-catalog GET '/storefront-catalog?slug=__smoke__'

if [[ "$fail" -ne 0 ]]; then
  echo "Smoke edge functions: FALLÓ"
  exit 1
fi

echo "Smoke edge functions: OK"
