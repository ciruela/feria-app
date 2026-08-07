#!/usr/bin/env bash
# Configura Resend como SMTP custom de Supabase Auth (Management API).
#
# Requisitos en Resend:
#   - Dominio verificado (ej. armenext.com)
#   - API key con permiso de envío
#
# Variables:
#   RESEND_API_KEY          (requerido)  re_...
#   RESEND_FROM_EMAIL       (default: noreply@armenext.com)
#   RESEND_SENDER_NAME      (default: Armenext)
#   RESEND_SMTP_HOST        (default: smtp.resend.com)
#   RESEND_SMTP_PORT        (default: 465)
#   RESEND_SMTP_USER        (default: resend)
#   SUPABASE_ACCESS_TOKEN   (requerido)
#   PROJECT_REF             (default: ihotjvimurztbhrsiabs)
#
# Uso:
#   RESEND_API_KEY=re_... SUPABASE_ACCESS_TOKEN=sbp_... ./scripts/configure_resend_smtp.sh
set -euo pipefail

PROJECT_REF="${PROJECT_REF:-ihotjvimurztbhrsiabs}"
FROM_EMAIL="${RESEND_FROM_EMAIL:-noreply@armenext.com}"
SENDER_NAME="${RESEND_SENDER_NAME:-Armenext}"
SMTP_HOST="${RESEND_SMTP_HOST:-smtp.resend.com}"
SMTP_PORT="${RESEND_SMTP_PORT:-465}"
SMTP_USER="${RESEND_SMTP_USER:-resend}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: falta SUPABASE_ACCESS_TOKEN"
  exit 1
fi

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Error: falta RESEND_API_KEY"
  echo "Obtenelo en https://resend.com/api-keys"
  exit 1
fi

payload="$(jq -n \
  --arg from "$FROM_EMAIL" \
  --arg name "$SENDER_NAME" \
  --arg host "$SMTP_HOST" \
  --arg port "$SMTP_PORT" \
  --arg user "$SMTP_USER" \
  --arg pass "$RESEND_API_KEY" \
  '{
    external_email_enabled: true,
    mailer_autoconfirm: false,
    smtp_admin_email: $from,
    smtp_sender_name: $name,
    smtp_host: $host,
    smtp_port: $port,
    smtp_user: $user,
    smtp_pass: $pass
  }')"

echo "Configurando Resend SMTP en proyecto $PROJECT_REF ..."
echo "  From: $SENDER_NAME <$FROM_EMAIL>"
echo "  Host: $SMTP_HOST:$SMTP_PORT"

http_code="$(curl -sS -o /tmp/supabase_resend_smtp.json -w "%{http_code}" \
  -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$payload")"

if [[ "$http_code" != "200" ]]; then
  echo "Error HTTP $http_code:"
  cat /tmp/supabase_resend_smtp.json
  exit 1
fi

echo "✓ Resend SMTP configurado."
echo
echo "Próximos pasos:"
echo "  1. Verificá DKIM/SPF en Resend para armenext.com"
echo "  2. Subí rate limits en Supabase → Auth → Rate Limits (feria = muchos usuarios)"
echo "  3. Probá registro con un email externo (no solo team members)"
