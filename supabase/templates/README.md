# Templates de email — Armenext

Correos de autenticación de Supabase con branding **Cobre táctico** (logo Armenext, español, sin menciones a Supabase).

## Logo

El HTML referencia el logo público:

`https://app.armenext.com/email/armenext-lockup.png`

Ese archivo vive en `web/email/` y se publica con el deploy de Cloudflare Pages.

## Aplicar en producción (recomendado)

1. Token de acceso: [Supabase Account → Tokens](https://supabase.com/dashboard/account/tokens)
2. Ejecutar:

```bash
chmod +x scripts/email_template_html.sh scripts/apply_supabase_email_templates.sh
SUPABASE_ACCESS_TOKEN=sbp_... ./scripts/apply_supabase_email_templates.sh
```

Eso actualiza **Site URL** → `https://app.armenext.com` y los templates:

| Template | Asunto |
|----------|--------|
| Confirm signup | Confirmá tu cuenta en Armenext |
| Magic link | Tu enlace de acceso a Armenext |
| Reset password | Restablecer contraseña — Armenext |
| Invite user | Te invitaron a Armenext |
| Change email | Confirmá tu nuevo email — Armenext |
| Reauthentication | Tu código de verificación — Armenext |

## Manual (Dashboard)

Copiá el HTML de cada archivo `.html` en esta carpeta a:

**Dashboard → Authentication → Email Templates**

## Redirect URLs

En **Authentication → URL Configuration**, verificá:

- **Site URL:** `https://app.armenext.com`
- **Redirect URLs:** `https://app.armenext.com/**`, `https://*.armenext.com/**`

## SMTP (producción)

Para más de 2 emails/hora y mejor deliverability, configurá SMTP custom en **Authentication → SMTP Settings** (Resend, SendGrid, etc.).
