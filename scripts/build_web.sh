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

flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

echo "OK. Salida en build/web/"
