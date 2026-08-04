#!/usr/bin/env bash
# Compila (si hace falta) y publica build/web en Cloudflare Pages.
#
# Requisitos:
#   - npx (Node) o wrangler instalado globalmente
#   - CLOUDFLARE_API_TOKEN con permiso "Cloudflare Pages — Edit"
#   - CLOUDFLARE_ACCOUNT_ID (Dashboard → Workers & Pages → Overview, columna derecha)
#
# Uso:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/deploy_cloudflare_pages.sh
#   CLOUDFLARE_PAGES_PROJECT=feria-app ./scripts/deploy_cloudflare_pages.sh
#
# Primera vez: wrangler crea el proyecto Pages si no existe.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${SUPABASE_URL:?Falta SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Falta SUPABASE_ANON_KEY}"
: "${CLOUDFLARE_API_TOKEN:?Falta CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ACCOUNT_ID:?Falta CLOUDFLARE_ACCOUNT_ID}"

PROJECT_NAME="${CLOUDFLARE_PAGES_PROJECT:-feria-app}"
BRANCH="${CLOUDFLARE_PAGES_BRANCH:-production}"

if [[ ! -f build/web/index.html ]]; then
  echo "Compilando Flutter Web..."
  ./scripts/build_web.sh
fi

if command -v wrangler >/dev/null 2>&1; then
  WRANGLER=(wrangler)
else
  WRANGLER=(npx --yes wrangler)
fi

echo "Deploy a Cloudflare Pages: proyecto=$PROJECT_NAME rama=$BRANCH"
"${WRANGLER[@]}" pages deploy build/web \
  --project-name="$PROJECT_NAME" \
  --branch="$BRANCH"

echo "OK. Configurá el dominio custom en Pages → $PROJECT_NAME → Custom domains."
