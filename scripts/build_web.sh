#!/usr/bin/env bash
# Compila el panel web (Flutter Web) reutilizando el mismo codigo de la app.
#
# Uso:
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... ./scripts/build_web.sh
#
# Deploy: subir el contenido de build/web a cualquier hosting estatico
# (Vercel, Netlify, Cloudflare Pages, Firebase Hosting, o Supabase Storage).
# Para tenants por subdominio (pepe.tuapp.com) configurar un wildcard *.tuapp.com
# apuntando al mismo build; el slug se detecta desde la URL (ver lib/utils/tenant_slug.dart).
set -euo pipefail

: "${SUPABASE_URL:?Falta SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Falta SUPABASE_ANON_KEY}"

GIT_SHA="${GIT_SHA:-${GITHUB_SHA:-}}"
APP_VERSION="${APP_VERSION:-1.0.0}"
SENTRY_DSN="${SENTRY_DSN:-}"

DEFINES=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
  "--dart-define=APP_VERSION=${APP_VERSION}"
)

if [[ -n "$GIT_SHA" ]]; then
  DEFINES+=("--dart-define=GIT_SHA=${GIT_SHA}")
fi

if [[ -n "$SENTRY_DSN" ]]; then
  DEFINES+=("--dart-define=SENTRY_DSN=${SENTRY_DSN}")
fi

flutter build web --release "${DEFINES[@]}"

echo "OK. Salida en build/web/ (release=${APP_VERSION}+${GIT_SHA:-local})"
