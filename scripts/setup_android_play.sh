#!/usr/bin/env bash
# Setup completo para deploy automático a Google Play (una sola vez).
#
# 1. Keystore de firma (si no existe)
# 2. Verifica JSON de Play Console en .secrets/
# 3. Sube secrets a GitHub Actions
#
# Uso: ./scripts/setup_android_play.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/.secrets"
PLAY_JSON="$SECRETS_DIR/play-console-service-account.json"

echo "=== Setup Android Play Store (automático) ==="
echo

if [[ ! -f "$ROOT_DIR/android/key.properties" ]]; then
  echo "→ Paso 1: crear keystore de firma"
  "$ROOT_DIR/scripts/setup_android_keystore.sh"
else
  echo "→ Paso 1: keystore OK (android/key.properties existe)"
fi

echo
echo "→ Paso 2: JSON de Play Console"

if [[ ! -f "$PLAY_JSON" ]]; then
  mkdir -p "$SECRETS_DIR"
  echo
  echo "Falta el JSON de la service account."
  echo
  echo "1. Play Console → Setup → API access"
  echo "2. Link Google Cloud project → Create service account"
  echo "3. Download JSON"
  echo "4. Guardalo como:"
  echo "   $PLAY_JSON"
  echo "5. En Play Console, invitá la service account con:"
  echo "   - Release apps to testing tracks"
  echo "   - View app information"
  echo
  read -r -p "¿Ya guardaste el JSON? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Volvé a ejecutar este script cuando tengas el JSON."
    exit 1
  fi
  if [[ ! -f "$PLAY_JSON" ]]; then
    OTHER="$(find "$SECRETS_DIR" -maxdepth 1 -name '*.json' 2>/dev/null | head -1 || true)"
    if [[ -n "$OTHER" ]]; then
      echo "Encontré: $OTHER"
      ln -sf "$(basename "$OTHER")" "$PLAY_JSON" 2>/dev/null || cp "$OTHER" "$PLAY_JSON"
    else
      echo "No encontré ningún .json en $SECRETS_DIR"
      exit 1
    fi
  fi
else
  echo "JSON OK: $PLAY_JSON"
fi

echo
echo "→ Paso 3: subir secrets a GitHub"
"$ROOT_DIR/scripts/load_android_secrets_to_github.sh"

echo
echo "=== Listo ==="
echo
echo "Play Console (manual, una sola vez):"
echo "  - Crear app 'Armenext' con package com.armeria.feria.app_feria"
echo "  - Completar ficha mínima + clasificación de contenido"
echo
echo "Deploy:"
echo "  GitHub → Actions → Android Play Store → Run workflow → track: internal"
