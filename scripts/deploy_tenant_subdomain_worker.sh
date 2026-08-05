#!/usr/bin/env bash
# Publica el Worker que enruta *.armenext.com → feria-app.pages.dev
#
# Requisitos:
#   - CLOUDFLARE_API_TOKEN (Account → Workers Scripts → Edit)
#   - CLOUDFLARE_ACCOUNT_ID
#
# Uso:
#   CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... ./scripts/deploy_tenant_subdomain_worker.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKER_DIR="$ROOT_DIR/cloudflare/tenant-subdomain-proxy"

: "${CLOUDFLARE_API_TOKEN:?Falta CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ACCOUNT_ID:?Falta CLOUDFLARE_ACCOUNT_ID}"

if command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler)
fi

cd "$WORKER_DIR"
echo "Deploy Worker feria-tenant-subdomains (*.armenext.com)..."
CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
  "${WRANGLER[@]}" deploy

echo "OK. Probá https://urbantactical.armenext.com y https://worldguns.armenext.com"
