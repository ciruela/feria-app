#!/usr/bin/env bash
# Aplica templates de email de auth con branding Armenext al proyecto Supabase hosted.
#
# Requisitos:
#   - curl, jq, bash
#   - SUPABASE_ACCESS_TOKEN (https://supabase.com/dashboard/account/tokens)
#   - PROJECT_REF (default: ihotjvimurztbhrsiabs)
#
# Uso:
#   SUPABASE_ACCESS_TOKEN=sbp_... ./scripts/apply_supabase_email_templates.sh
#
# También actualiza Site URL → https://app.armenext.com (redirect URLs no se tocan).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_REF="${PROJECT_REF:-ihotjvimurztbhrsiabs}"
SITE_URL="${ARMENEXT_SITE_URL:-https://app.armenext.com}"

if [[ -z "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
  echo "Error: falta SUPABASE_ACCESS_TOKEN"
  echo "Obtenelo en https://supabase.com/dashboard/account/tokens"
  exit 1
fi

html_for() {
  bash "$ROOT_DIR/scripts/email_template_html.sh" "$1"
}

confirmation_html="$(html_for confirmation)"
magic_link_html="$(html_for magic_link)"
recovery_html="$(html_for recovery)"
invite_html="$(html_for invite)"
email_change_html="$(html_for email_change)"
reauth_html="$(html_for reauthentication)"

payload="$(jq -n \
  --arg site "$SITE_URL" \
  --arg confirmation_html "$confirmation_html" \
  --arg magic_link_html "$magic_link_html" \
  --arg recovery_html "$recovery_html" \
  --arg invite_html "$invite_html" \
  --arg email_change_html "$email_change_html" \
  --arg reauth_html "$reauth_html" \
  '{
    site_url: $site,
    mailer_subjects_confirmation: "Confirmá tu cuenta en Armenext",
    mailer_templates_confirmation_content: $confirmation_html,
    mailer_subjects_magic_link: "Tu enlace de acceso a Armenext",
    mailer_templates_magic_link_content: $magic_link_html,
    mailer_subjects_recovery: "Restablecer contraseña — Armenext",
    mailer_templates_recovery_content: $recovery_html,
    mailer_subjects_invite: "Te invitaron a Armenext",
    mailer_templates_invite_content: $invite_html,
    mailer_subjects_email_change: "Confirmá tu nuevo email — Armenext",
    mailer_templates_email_change_content: $email_change_html,
    mailer_subjects_reauthentication: "Tu código de verificación — Armenext",
    mailer_templates_reauthentication_content: $reauth_html
  }')"

echo "Aplicando templates de email a proyecto $PROJECT_REF ..."
echo "Site URL → $SITE_URL"
echo "Logo → ${ARMENEXT_EMAIL_LOGO_URL:-https://app.armenext.com/email/armenext-lockup.png}"

http_code="$(curl -sS -o /tmp/supabase_auth_config.json -w "%{http_code}" \
  -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$payload")"

if [[ "$http_code" != "200" ]]; then
  echo "Error HTTP $http_code:"
  cat /tmp/supabase_auth_config.json
  exit 1
fi

echo "✓ Templates aplicados."
echo
echo "Verificá en Dashboard → Authentication → Email Templates"
echo "Probá registrando un usuario de prueba para ver el correo nuevo."
