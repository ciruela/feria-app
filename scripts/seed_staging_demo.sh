#!/usr/bin/env bash
# Aplica el seed de demo en Supabase STAGING.
# Requiere: SUPABASE_ACCESS_TOKEN
#
# Uso:
#   export SUPABASE_ACCESS_TOKEN=sbp_...
#   ./scripts/seed_staging_demo.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REF="${SUPABASE_STAGING_REF:-edwpfzdhitlnvewubebx}"

export PROJECT_REF
"$ROOT_DIR/scripts/apply_supabase_migration.sh" "$ROOT_DIR/supabase/seeds/staging_demo.sql"
echo "OK: seed staging_demo aplicado en $PROJECT_REF"
