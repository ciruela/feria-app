-- 046_admin_master_pin.sql
-- PIN maestro de administración por tenant (sync web/mobile).
-- Antes: solo hash; la app verifica con el mismo esquema que administradores.

alter table public.app_config
  add column if not exists admin_master_pin_hash text;

comment on column public.app_config.admin_master_pin_hash is
  'SHA-256 hex del PIN maestro (salt feria-armeria::pin::v1). Null = default 2580 en app.';
