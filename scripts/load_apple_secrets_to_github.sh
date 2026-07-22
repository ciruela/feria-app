#!/usr/bin/env bash
# Carga secrets de Apple en GitHub Actions.
# Creá App Store Connect API Key y guardá en .secrets/:
#   .secrets/apple-api.env   → ISSUER_ID=...  KEY_ID=...
#   .secrets/AuthKey_XXXXX.p8
#
# Uso: ./scripts/load_apple_secrets_to_github.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/.secrets"
ENV_FILE="$SECRETS_DIR/apple-api.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta $ENV_FILE"
  echo
  echo "Creá la API Key en:"
  echo "  https://appstoreconnect.apple.com/access/integrations/api"
  echo
  echo "Archivo .secrets/apple-api.env:"
  echo "  ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  echo "  KEY_ID=ABC123XYZ"
  echo
  echo "Y el .p8 descargado en .secrets/AuthKey_\${KEY_ID}.p8"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

P8="$SECRETS_DIR/AuthKey_${KEY_ID}.p8"
if [[ ! -f "$P8" ]]; then
  P8="$(find "$SECRETS_DIR" -name 'AuthKey_*.p8' | head -1)"
fi

if [[ -z "${ISSUER_ID:-}" || -z "${KEY_ID:-}" || ! -f "$P8" ]]; then
  echo "Completá ISSUER_ID, KEY_ID en apple-api.env y el archivo .p8 en .secrets/"
  exit 1
fi

gh secret set APP_STORE_CONNECT_ISSUER_ID --body "$ISSUER_ID"
gh secret set APP_STORE_CONNECT_KEY_ID --body "$KEY_ID"
gh secret set APP_STORE_CONNECT_PRIVATE_KEY < "$P8"

if [[ -z "${APP_STORE_CERTIFICATE_KEY:-}" ]]; then
  APP_STORE_CERTIFICATE_KEY="$(openssl rand -base64 24 | tr -d '\n')"
fi
gh secret set APP_STORE_CERTIFICATE_KEY --body "$APP_STORE_CERTIFICATE_KEY"

echo "✓ Secrets de Apple cargados en GitHub"
gh secret list | rg 'APP_STORE|SUPABASE'
