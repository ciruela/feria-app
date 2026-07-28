-- 009_auth_hook_rls.sql
-- ---------------------------------------------------------------------
-- FIX: el JWT sale sin `tenant_id` / con `is_platform_admin=false`.
--
-- Causa: `custom_access_token_hook` (definido en 001/003) NO es
-- `security definer` y se ejecuta como el rol `supabase_auth_admin`
-- durante la emision del token, cuando todavia NO hay `auth.uid()` ni
-- claims. Al leer `public.memberships` y `public.platform_admins`, la RLS
-- estricta cerrada en 007 (policies que exigen is_platform_admin() /
-- user_id = auth.uid() / tenant_id = current_tenant_id()) filtra TODAS
-- las filas -> el hook no encuentra membership -> emite un JWT sin
-- tenant_id. Eso rompe cualquier escritura via RLS (ej: import Excel en
-- `productos`).
--
-- Solucion (patron recomendado por Supabase para Auth Hooks): permitir
-- explicitamente que el rol `supabase_auth_admin` lea esas tablas.
-- Es seguro: la policy esta acotada al rol del sistema de Auth, no
-- afecta a `authenticated` ni `anon`.
--
-- Aplicar en: Supabase Dashboard -> SQL Editor.
-- Verificar ademas que el hook este habilitado en:
--   Authentication -> Hooks -> Customize Access Token (JWT) Claims
--   = public.custom_access_token_hook
-- ---------------------------------------------------------------------

-- Grants (idempotentes; ya presentes en 001, se repiten por seguridad).
grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
grant select on public.memberships to supabase_auth_admin;
grant select on public.platform_admins to supabase_auth_admin;

-- Policies que permiten al hook (rol supabase_auth_admin) leer las tablas
-- que necesita para construir los claims, pese a la RLS estricta.
drop policy if exists "auth_admin_read_memberships" on public.memberships;
create policy "auth_admin_read_memberships" on public.memberships
  as permissive for select to supabase_auth_admin
  using (true);

drop policy if exists "auth_admin_read_platform_admins" on public.platform_admins;
create policy "auth_admin_read_platform_admins" on public.platform_admins
  as permissive for select to supabase_auth_admin
  using (true);

-- ---------------------------------------------------------------------
-- Verificacion (opcional): simula el hook para un usuario y confirma que
-- ahora el claim tenant_id aparece. Reemplazar <AUTH_USER_ID>.
--
--   select public.custom_access_token_hook(
--     jsonb_build_object(
--       'user_id', '<AUTH_USER_ID>',
--       'claims', '{}'::jsonb
--     )
--   ) -> 'claims';
--
-- Debe devolver algo como:
--   { "tenant_id": "....", "app_role": "owner", "is_platform_admin": true }
--
-- Tras aplicar: en la app, CERRAR SESION y volver a entrar para forzar un
-- token nuevo con los claims correctos.
-- ---------------------------------------------------------------------
