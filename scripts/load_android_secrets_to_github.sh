#!/usr/bin/env bash
# Carga secrets de Android (keystore + JSON Play Console) en GitHub Actions.
#
# Requisitos locales:
#   android/key.properties          → ./scripts/setup_android_keystore.sh
#   .secrets/play-console-service-account.json   → JSON de Play Console → API access
#
# Opcional: .env con SUPABASE_URL y SUPABASE_ANON_KEY (si no están ya en GitHub)
#
# Uso: ./scripts/load_android_secrets_to_github.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/.secrets"
KEY_PROPS="$ROOT_DIR/android/key.properties"
PLAY_JSON="$SECRETS_DIR/play-console-service-account.json"

if [[ ! -f "$KEY_PROPS" ]]; then
  echo "Falta $KEY_PROPS"
  echo "Ejecutá primero: ./scripts/setup_android_keystore.sh"
  exit 1
fi

if [[ ! -f "$PLAY_JSON" ]]; then
  PLAY_JSON="$(find "$SECRETS_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | head -1 || true)"
fi

if [[ -z "$PLAY_JSON" || ! -f "$PLAY_JSON" ]]; then
  echo "Falta el JSON de Play Console."
  echo
  echo "Guardalo en:"
  echo "  $SECRETS_DIR/play-console-service-account.json"
  echo
  echo "Play Console → Setup → API access → Create service account → Download JSON"
  echo "Luego invitá la service account con permiso 'Release to testing tracks'."
  exit 1
fi

# shellcheck disable=SC1090
source "$KEY_PROPS"

if [[ -z "${storeFile:-}" || ! -f "$storeFile" ]]; then
  echo "storeFile inválido en key.properties: ${storeFile:-<vacío>}"
  exit 1
fi

if [[ -z "${storePassword:-}" || -z "${keyPassword:-}" || -z "${keyAlias:-}" ]]; then
  echo "Completá storePassword, keyPassword y keyAlias en key.properties"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Instalá GitHub CLI: https://cli.github.com/"
  exit 1
fi

echo "Cargando secrets de Android en GitHub..."

KEYSTORE_B64="$(base64 < "$storeFile" | tr -d '\n')"

gh secret set ANDROID_KEYSTORE_BASE64 --body "$KEYSTORE_B64"
gh secret set ANDROID_KEYSTORE_PASSWORD --body "$storePassword"
gh secret set ANDROID_KEY_ALIAS --body "$keyAlias"
gh secret set ANDROID_KEY_PASSWORD --body "$keyPassword"
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < "$PLAY_JSON"

ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    [[ -z "$key" || "$key" == \#* ]] && continue
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    case "$key" in
      SUPABASE_URL|SUPABASE_ANON_KEY|SENTRY_DSN)
        gh secret set "$key" --body "$value"
        echo "  ✓ $key"
        ;;
    esac
  done < "$ENV_FILE"
fi

echo
echo "✓ Secrets de Android cargados en GitHub"
echo
echo "Secrets activos:"
gh secret list | rg 'ANDROID|GOOGLE_PLAY|SUPABASE|SENTRY' || true
echo
echo "Deploy automático:"
echo "  GitHub → Actions → Android Play Store → Run workflow"
echo "  (requiere CI verde en el mismo commit)"
