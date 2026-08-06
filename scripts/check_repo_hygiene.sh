#!/usr/bin/env bash
# AR-21 / AR-24: gobernanza mínima del repo que hoy ninguna herramienta mira.
#   1. Toda Edge Function con carpeta debe estar en el workflow de deploy.
#   2. Toda Edge Function debe declarar verify_jwt en supabase/config.toml.
#   3. supabase/config.toml debe existir.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEPLOY_WF=".github/workflows/supabase-edge-functions.yml"
CONFIG="supabase/config.toml"
fail=0

if [[ ! -f "$CONFIG" ]]; then
  echo "FAIL: falta $CONFIG (verify_jwt por función, AR-24)"
  exit 1
fi
if [[ ! -f "$DEPLOY_WF" ]]; then
  echo "FAIL: falta $DEPLOY_WF"
  exit 1
fi

for dir in supabase/functions/*/; do
  fn="$(basename "$dir")"
  [[ -f "$dir/index.ts" ]] || continue

  if ! grep -q "$fn" "$DEPLOY_WF"; then
    echo "FAIL: la función '$fn' no está en $DEPLOY_WF (CI no la despliega)"
    fail=1
  fi
  if ! grep -q "functions.$fn" "$CONFIG"; then
    echo "FAIL: la función '$fn' no declara verify_jwt en $CONFIG"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "Repo hygiene: FALLÓ"
  exit 1
fi

echo "Repo hygiene: OK"
