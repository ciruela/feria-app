# Supabase — feria-app

Backend multi-tenant para armerías. Las migraciones viven en `migrations/` y se aplican **en orden** desde el SQL Editor del dashboard (o con la CLI de Supabase).

## Proyecto nuevo (desde cero)

1. Crear proyecto en [supabase.com](https://supabase.com).
2. Ejecutar las migraciones **001 → 012** (ver tabla abajo), una por una.
3. Dashboard → **Authentication → Hooks → Access Token** → activar `custom_access_token_hook`.
4. Dashboard → **Authentication → Providers → Email** → activar **Confirm email**.
5. Dashboard → **Authentication → Providers → Anonymous sign-ins** → **ON** (portal vendedores).
6. Crear usuario admin en Authentication → Users y vincularlo:
   ```sql
   insert into public.memberships (user_id, tenant_id, rol, nombre)
   values ('<auth_user_id>', '<tenant_id>', 'owner', 'Dueño');
   ```
7. (Opcional) Super admin de plataforma:
   ```sql
   insert into public.platform_admins (user_id, nombre)
   values ('<auth_user_id>', 'Nombre');
   ```
8. Desplegar Edge Functions si usás tienda web o métricas:
   ```bash
   supabase functions deploy platform-metrics
   supabase functions deploy storefront-catalog storefront-order
   ```
9. Copiar `SUPABASE_URL` y `SUPABASE_ANON_KEY` a `.env` en la raíz del repo.

Verificar con `./scripts/verify_supabase.sh`.

## Migraciones (orden)

| Archivo | Qué hace |
|---------|----------|
| `001_multitenant.sql` | Tenants, memberships, `tenant_id`, JWT hook, backfill. **No** ejecutar la sección final "ACTIVAR RLS ESTRICTA" hasta el paso 007. |
| `002_storefront.sql` | Tienda web (opcional). |
| `003_tenant_switching.sql` | Cambio de armería activa en el JWT. |
| `004_platform_admin_check.sql` | Helpers para panel super admin. |
| `005_registration.sql` | Registro self-service de armerías. |
| `007_close_rls.sql` | RLS estricta por tenant (reemplaza policies abiertas). |
| `008_provision_guard.sql` | Refuerzo del guard de provisioning. **Opcional** — no aplicada en prod actual. |
| `009_auth_hook_rls.sql` | RLS alineada con el auth hook. |
| `014_storage_buckets.sql` | Buckets `feria-comprobantes` + `feria-fotos` y policies (obligatorio para ventas PDF). |
| `015_ventas_pdf_path.sql` | Columna `ventas.pdf_path` para guardar la ruta del comprobante en Storage. |
| `011_team_members.sql` | Invitar miembros, listar equipo con email. |
| `012_seller_portal.sql` | Portal vendedores (slug + clave, `pgcrypto`). |

### Archivo archivado

| Archivo | Notas |
|---------|-------|
| `archive/006_world_guns_tenant.sql` | One-off de producción: migró datos de `default` a `world-guns`. **No** volver a ejecutar. |

## Producción existente

Si el proyecto ya tiene migraciones aplicadas, ejecutá **solo las que falten** (010–012 si aún no están). No re-ejecutar 001 ni 006.

## Seguridad

- La **service role key** solo en Edge Functions, nunca en la app.
- Aislamiento por RLS + claims JWT. Probar con `tests/rls_isolation_test.sql`.
- PIN y claves de portal se guardan hasheados (SHA-256).

## App Flutter

Variables en `.env` o `--dart-define`:

| Variable | Descripción |
|----------|-------------|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | anon public key |

Carga inicial de catálogo: **Administración → Publicar catálogo a Supabase** (desde JSON local).
