#!/usr/bin/env bash
# Crea o actualiza .env con credenciales de Supabase.
# Uso: ./scripts/setup_supabase_env.sh
#   o: ./scripts/setup_supabase_env.sh https://xxx.supabase.co eyJ...

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

url="${1:-}"
key="${2:-}"

if [[ -z "$url" ]]; then
  echo "=== Configurar Supabase para feria-app ==="
  echo
  echo "Obtené las credenciales en: https://supabase.com/dashboard"
  echo "  → Tu proyecto → Settings → API"
  echo "  → Project URL"
  echo "  → anon public key"
  echo
  read -r -p "SUPABASE_URL: " url
fi

if [[ -z "$key" ]]; then
  read -r -p "SUPABASE_ANON_KEY: " key
fi

url="${url%/}"

if [[ ! "$url" =~ ^https://.*\.supabase\.co$ ]]; then
  echo "Error: SUPABASE_URL debe ser https://TU_PROYECTO.supabase.co"
  exit 1
fi

if [[ ${#key} -lt 20 ]]; then
  echo "Error: SUPABASE_ANON_KEY parece inválida"
  exit 1
fi

cat > "$ENV_FILE" <<EOF
SUPABASE_URL=$url
SUPABASE_ANON_KEY=$key
EOF

chmod 600 "$ENV_FILE" 2>/dev/null || true

echo
echo "✓ Guardado en .env (no se commitea a git)"
echo
echo "Siguiente paso: ./scripts/verify_supabase.sh"
