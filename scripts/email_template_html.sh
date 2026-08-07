#!/usr/bin/env bash
# Genera HTML de emails de auth con branding Armenext (Cobre táctico).
# Uso interno: scripts/apply_supabase_email_templates.sh

set -euo pipefail

LOGO_URL="${ARMENEXT_EMAIL_LOGO_URL:-https://app.armenext.com/email/armenext-lockup.png}"
APP_URL="${ARMENEXT_APP_URL:-https://app.armenext.com}"

wrap_email() {
  local title="$1"
  local body="$2"
  cat <<EOF
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:#0D0B0A;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#0D0B0A;">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background-color:#1A1613;border:1px solid #2C2721;border-radius:8px;">
          <tr>
            <td align="center" style="padding:32px 28px 8px;">
              <img src="${LOGO_URL}" alt="Armenext" width="168" height="40" style="display:block;border:0;outline:none;text-decoration:none;max-width:168px;height:auto;" />
            </td>
          </tr>
          <tr>
            <td style="padding:8px 28px 28px;color:#EDE7DE;font-size:15px;line-height:1.55;">
              ${body}
            </td>
          </tr>
          <tr>
            <td style="padding:20px 28px 28px;border-top:1px solid #2C2721;color:#9A9088;font-size:12px;line-height:1.5;">
              Este mensaje fue enviado por <strong style="color:#EDE7DE;">Armenext</strong>, plataforma de gestión para armerías.<br>
              Si no solicitaste este correo, podés ignorarlo con tranquilidad.
            </td>
          </tr>
        </table>
        <p style="margin:20px 0 0;color:#9A9088;font-size:11px;line-height:1.4;">
          <a href="${APP_URL}" style="color:#E2622F;text-decoration:none;">app.armenext.com</a>
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
EOF
}

button_html() {
  local label="$1"
  local url="$2"
  cat <<EOF
<table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px 0;">
  <tr>
    <td align="center" style="border-radius:4px;background-color:#E2622F;">
      <a href="${url}" target="_blank" style="display:inline-block;padding:14px 28px;font-size:14px;font-weight:700;color:#3D1607;text-decoration:none;letter-spacing:0.3px;">${label}</a>
    </td>
  </tr>
</table>
EOF
}

# Nota: los botones usan placeholders reemplazados después porque Go templates usan {{ }}

confirmation_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Confirmá tu cuenta</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Gracias por registrarte en Armenext. Para activar tu cuenta y empezar a usar la plataforma, confirmá tu email.</p>
__BUTTON_CONFIRM__
<p style="margin:16px 0 0;color:#9A9088;font-size:13px;">El enlace expira en breve y solo puede usarse una vez.</p>
<p style="margin:20px 0 0;padding:16px;background-color:#241E1A;border:1px solid #2C2721;border-radius:4px;color:#EDE7DE;font-size:13px;">
  <span style="display:block;margin-bottom:6px;color:#9A9088;">Código de verificación</span>
  <span style="font-size:24px;font-weight:800;letter-spacing:4px;color:#E2622F;">{{ .Token }}</span>
</p>
EOF
}

magic_link_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Accedé a Armenext</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Recibimos una solicitud para iniciar sesión con <strong>{{ .Email }}</strong>. Tocá el botón para continuar.</p>
__BUTTON_SIGNIN__
<p style="margin:16px 0 0;color:#9A9088;font-size:13px;">Si no fuiste vos, ignorá este correo. Tu cuenta sigue protegida.</p>
EOF
}

recovery_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Restablecer contraseña</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Recibimos un pedido para cambiar la contraseña de <strong>{{ .Email }}</strong>.</p>
__BUTTON_RESET__
<p style="margin:16px 0 0;color:#9A9088;font-size:13px;">Si no solicitaste el cambio, no hagas nada: tu contraseña actual sigue vigente.</p>
EOF
}

invite_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Te invitaron a Armenext</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Te dieron acceso a una armería en la plataforma. Creá tu contraseña y empezá a trabajar.</p>
__BUTTON_INVITE__
EOF
}

email_change_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Confirmá tu nuevo email</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Pediste cambiar tu dirección de correo a <strong>{{ .NewEmail }}</strong>.</p>
__BUTTON_CHANGE__
EOF
}

reauthentication_body() {
  cat <<'EOF'
<h1 style="margin:0 0 12px;font-size:22px;font-weight:800;color:#EDE7DE;">Código de verificación</h1>
<p style="margin:0 0 16px;color:#EDE7DE;">Usá este código para confirmar una acción sensible en tu cuenta:</p>
<p style="margin:0;padding:20px;background-color:#241E1A;border:1px solid #2C2721;border-radius:4px;text-align:center;font-size:32px;font-weight:800;letter-spacing:6px;color:#E2622F;">{{ .Token }}</p>
<p style="margin:16px 0 0;color:#9A9088;font-size:13px;">Expira en pocos minutos.</p>
EOF
}

build_template() {
  local title="$1"
  local body_fn="$2"
  local button_label="${3:-}"
  local body
  body="$($body_fn)"
  if [[ -n "$button_label" ]]; then
    local btn
    btn="$(button_html "$button_label" '{{ .ConfirmationURL }}')"
    body="${body/__BUTTON_CONFIRM__/$btn}"
    body="${body/__BUTTON_SIGNIN__/$btn}"
    body="${body/__BUTTON_RESET__/$btn}"
    body="${body/__BUTTON_INVITE__/$btn}"
    body="${body/__BUTTON_CHANGE__/$btn}"
  fi
  wrap_email "$title" "$body"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    confirmation) build_template "Confirmá tu cuenta" confirmation_body "CONFIRMAR EMAIL" ;;
    magic_link) build_template "Accedé a Armenext" magic_link_body "INICIAR SESIÓN" ;;
    recovery) build_template "Restablecer contraseña" recovery_body "NUEVA CONTRASEÑA" ;;
    invite) build_template "Invitación Armenext" invite_body "ACEPTAR INVITACIÓN" ;;
    email_change) build_template "Confirmar nuevo email" email_change_body "CONFIRMAR EMAIL" ;;
    reauthentication) build_template "Código de verificación" reauthentication_body "" ;;
    *) echo "Uso: $0 {confirmation|magic_link|recovery|invite|email_change|reauthentication}" >&2; exit 1 ;;
  esac
fi
