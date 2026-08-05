#!/usr/bin/env bash
# Sincroniza secrets de Cloudflare en Supabase (edge function register-tenant-subdomain).
#
# Uso local (CLI ya logueado con supabase login):
#   CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=... ./scripts/sync_cloudflare_secrets_to_supabase.sh
#
# O creá .secrets/cloudflare.env con:
#   CLOUDFLARE_API_TOKEN=...
#   CLOUDFLARE_ACCOUNT_ID=...
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.secrets/cloudflare.env"
PROJECT_REF="${SUPABASE_PROJECT_REF:-ihotjvimurztbhrsiabs}"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

: "${CLOUDFLARE_API_TOKEN:?Falta CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ACCOUNT_ID:?Falta CLOUDFLARE_ACCOUNT_ID}"

supabase secrets set \
  CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  CLOUDFLARE_ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID" \
  CLOUDFLARE_PAGES_PROJECT="${CLOUDFLARE_PAGES_PROJECT:-feria-app}" \
  TENANT_APP_DOMAIN="${TENANT_APP_DOMAIN:-armenext.com}" \
  --project-ref "$PROJECT_REF"

echo "OK. Secrets Cloudflare sincronizados en Supabase ($PROJECT_REF)."
