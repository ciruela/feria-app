#!/usr/bin/env bash
# Ayuda para cargar secrets de GitHub Actions (iOS TestFlight).
# Uso: ./scripts/prepare_ci_secrets.sh

set -euo pipefail

echo "=== Secrets para GitHub → feria-app → Settings → Secrets → Actions ==="
echo

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  echo "Desde .env (copiá manualmente a GitHub Secrets):"
  grep -E '^SUPABASE_URL=|^SUPABASE_ANON_KEY=' "$ROOT_DIR/.env" || true
  echo
else
  echo "⚠ No hay .env — agregá SUPABASE_URL y SUPABASE_ANON_KEY a mano en GitHub."
  echo
fi

echo "App Store Connect API (.p8):"
echo "  1. https://appstoreconnect.apple.com/access/integrations/api"
echo "  2. Generá una key con rol Admin o App Manager"
echo "  3. Secrets:"
echo "     APP_STORE_CONNECT_ISSUER_ID  (Issuer ID de la página)"
echo "     APP_STORE_CONNECT_KEY_ID     (Key ID, ej. ABC123XYZ)"
echo "     APP_STORE_CONNECT_PRIVATE_KEY (pegá todo el archivo AuthKey_XXX.p8)"
echo

echo "Certificado de distribución (.p12):"
echo "  1. Keychain Access → buscá 'Apple Distribution' o 'iPhone Distribution'"
echo "  2. Click derecho → Exportar → guardá como distribution.p12"
echo "  3. Secret IOS_DISTRIBUTION_CERTIFICATE_PASSWORD = la contraseña que elijas"
echo "  4. Secret IOS_DISTRIBUTION_CERTIFICATE_P12 = base64 del .p12:"
echo

P12="${1:-}"
if [[ -n "$P12" && -f "$P12" ]]; then
  echo "--- base64 (copiá a IOS_DISTRIBUTION_CERTIFICATE_P12) ---"
  base64 < "$P12" | pbcopy
  echo "(copiado al portapapeles, $(wc -c < <(base64 < "$P12")) caracteres)"
else
  echo "  base64 -i distribution.p12 | pbcopy"
  echo "  (o: ./scripts/prepare_ci_secrets.sh ruta/a/distribution.p12)"
fi

echo
echo "Cuando estén los secrets, un push a main con cambios en lib/ dispara el CI."
echo "TestFlight avisa a los testers; pueden activar actualizaciones automáticas."
