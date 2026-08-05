#!/usr/bin/env bash
# Registra subdominios tenant como custom domain en Cloudflare Pages.
#
# Pages no acepta wildcard en la UI; cada *.armenext.com debe registrarse en el
# proyecto feria-app (o usar el Worker feria-tenant-subdomains).
#
# Uso:
#   CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... ./scripts/cloudflare_register_tenant_domains.sh
#   ./scripts/cloudflare_register_tenant_domains.sh urbantactical worldguns
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${CLOUDFLARE_API_TOKEN:?Falta CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ACCOUNT_ID:?Falta CLOUDFLARE_ACCOUNT_ID}"

PROJECT="${CLOUDFLARE_PAGES_PROJECT:-feria-app}"
BASE_DOMAIN="${TENANT_APP_DOMAIN:-armenext.com}"
CONFIG="$ROOT_DIR/cloudflare/tenant-domains.json"

register_domain() {
  local host="$1"
  echo "→ Registrando ${host} en Pages (${PROJECT})…"
  local response
  response="$(curl -sS -w "\n%{http_code}" -X POST \
    "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/pages/projects/${PROJECT}/domains" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"name\":\"${host}\"}")"
  local code="${response##*$'\n'}"
  local body="${response%$'\n'*}"

  if [[ "$code" == "200" || "$code" == "201" ]]; then
    echo "  OK"
    return 0
  fi

  if echo "$body" | grep -qi 'already exists\|duplicate\|already been taken'; then
    echo "  Ya existía (OK)"
    return 0
  fi

  echo "  Error HTTP ${code}: ${body}" >&2
  return 1
}

subdomain_to_host() {
  local sub="$1"
  sub="${sub//-/}"
  sub="$(echo "$sub" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"
  echo "${sub}.${BASE_DOMAIN}"
}

SUBDOMAINS=()
if (($# > 0)); then
  SUBDOMAINS=("$@")
elif [[ -f "$CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  mapfile -t SUBDOMAINS < <(jq -r '.subdomains[]' "$CONFIG")
else
  echo "Sin subdominios. Pasá args o instalá jq + ${CONFIG}" >&2
  exit 1
fi

failed=0
for sub in "${SUBDOMAINS[@]}"; do
  host="$(subdomain_to_host "$sub")"
  register_domain "$host" || failed=1
done

if ((failed != 0)); then
  exit 1
fi

echo "Listo. Probá: https://$(subdomain_to_host "${SUBDOMAINS[0]}")"
