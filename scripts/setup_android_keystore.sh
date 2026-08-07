#!/usr/bin/env bash
# Genera el keystore de Play Store y android/key.properties (una sola vez).
#
# Uso: ./scripts/setup_android_keystore.sh
#
# Guardá una copia del .jks y las contraseñas en un lugar seguro.
# Si perdés el keystore, no podés actualizar la app en Google Play.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$ROOT_DIR/.secrets"
KEYSTORE="$SECRETS_DIR/android-upload-keystore.jks"
KEY_PROPS="$ROOT_DIR/android/key.properties"
KEY_PROPS_EXAMPLE="$ROOT_DIR/android/key.properties.example"
ALIAS="upload"

mkdir -p "$SECRETS_DIR"

if [[ -f "$KEY_PROPS" ]]; then
  echo "Ya existe $KEY_PROPS"
  read -r -p "¿Regenerar keystore y sobrescribir? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Cancelado."
    exit 0
  fi
fi

if [[ -f "$KEYSTORE" ]]; then
  echo "Ya existe keystore: $KEYSTORE"
  read -r -p "¿Regenerar keystore? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    USE_EXISTING=true
  else
    USE_EXISTING=false
  fi
else
  USE_EXISTING=false
fi

echo
echo "Contraseñas del keystore (mín. 6 caracteres). Usá la misma para store y key si querés simplificar."
read -r -s -p "Store password: " STORE_PASS
echo
read -r -s -p "Key password (Enter = igual que store): " KEY_PASS
echo
KEY_PASS="${KEY_PASS:-$STORE_PASS}"

if [[ ${#STORE_PASS} -lt 6 ]]; then
  echo "Error: la contraseña debe tener al menos 6 caracteres."
  exit 1
fi

if [[ "$USE_EXISTING" != "true" ]]; then
  echo "Generando keystore en $KEYSTORE ..."
  keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$STORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=Armenext, OU=Mobile, O=Armeria, L=Buenos Aires, C=AR"
fi

cat > "$KEY_PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF

chmod 600 "$KEY_PROPS"

echo
echo "✓ Keystore: $KEYSTORE"
echo "✓ Config:   $KEY_PROPS"
echo
echo "Probá el build:"
echo "  ./scripts/build_android_aab.sh"
echo
echo "Para CI (opcional):"
echo "  ./scripts/load_android_secrets_to_github.sh"
echo
echo "IMPORTANTE: hacé backup del .jks y las contraseñas fuera de este repo."
