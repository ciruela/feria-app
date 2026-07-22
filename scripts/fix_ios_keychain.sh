#!/usr/bin/env bash
set -euo pipefail

echo "Configura el llavero para que codesign no pida la clave en cada compilación."
echo
echo "IMPORTANTE: usá la contraseña con la que ENTRÁS A LA MAC."
echo "No es la del iPhone ni la de Gmail (salvo que sea la misma)."
echo
read -s -p "Contraseña de la Mac: " PASS
echo

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

security unlock-keychain -p "$PASS" "$KEYCHAIN"

# Permiso global para herramientas de Apple / codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KEYCHAIN"

# Refuerzo por cada certificado de desarrollo (hay varios duplicados)
while IFS= read -r line; do
  name="${line#*\"}"
  name="${name%\"*}"
  [[ -z "$name" ]] && continue
  echo "Ajustando: $name"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KEYCHAIN" -D "$name" -t private 2>/dev/null || true
done < <(security find-identity -v -p codesigning | sed -n 's/.*"\(.*\)"/\1/p')

echo
echo "Listo. Cerrá el cartel de codesign si sigue abierto (Denegar)"
echo "y volvé a compilar."
