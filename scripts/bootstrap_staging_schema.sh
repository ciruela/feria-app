#!/usr/bin/env bash
# Copia schema public de PROD a STAGING (estructura, sin datos).
# Requiere: supabase login + link a prod para el dump.
#
# Uso:
#   ./scripts/bootstrap_staging_schema.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROD_REF="${SUPABASE_PROD_REF:-ihotjvimurztbhrsiabs}"
STAGING_REF="${SUPABASE_STAGING_REF:-edwpfzdhitlnvewubebx}"
DUMP="/tmp/feria_prod_public_for_staging.sql"

echo "→ Dump schema public de prod ($PROD_REF)"
cd "$ROOT_DIR"
supabase link --project-ref "$PROD_REF" --yes
supabase db dump --linked --schema public -f "$DUMP"

echo "→ Aplicar schema en staging ($STAGING_REF)"
supabase link --project-ref "$STAGING_REF" --yes
supabase db query --linked -f "$DUMP"

echo "→ Seed demo (tenant staging-demo, producto, cliente DNI 30123456)"
export PROJECT_REF="$STAGING_REF"
"$ROOT_DIR/scripts/seed_staging_demo.sh"

echo "OK. Staging listo. Configurá .env.staging y creá usuario Auth + membership."
