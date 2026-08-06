-- =====================================================================
-- 034_revoke_function_execute.sql
-- ---------------------------------------------------------------------
-- AR-16 (API-001 / AUTH-003): en Supabase, `revoke ... from public` NO
-- quita el EXECUTE explícito que reciben anon/authenticated por
-- `alter default privileges ... grant execute on functions`.
--
-- 1) Cambia el default para que funciones nuevas no nazcan abiertas.
-- 2) Revoca EXECUTE de public/anon/authenticated en todas las funciones
--    de schema public y re-otorga solo donde corresponde.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Defaults: evitar recurrencia (roles que crean objetos en este proyecto)
-- ---------------------------------------------------------------------

alter default privileges in schema public
  revoke execute on functions from public;

alter default privileges in schema public
  revoke execute on functions from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;

-- supabase_admin: el rol de migración vía Management API no siempre puede
-- alterar defaults de otro rol; se intenta y se ignora si no hay permiso.
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    begin
      execute $q$
        alter default privileges for role supabase_admin in schema public
          revoke execute on functions from public
      $q$;
      execute $q$
        alter default privileges for role supabase_admin in schema public
          revoke execute on functions from anon, authenticated
      $q$;
    exception
      when insufficient_privilege then
        raise notice 'skip default privileges for supabase_admin (no privilege)';
    end;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Barrido: quitar EXECUTE de clientes en TODAS las funciones public
-- ---------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
  loop
    execute format('revoke all on function %s from public', r.sig);
    execute format('revoke all on function %s from anon, authenticated', r.sig);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Re-grants: helpers usados en RLS (invoker = rol de la query)
-- ---------------------------------------------------------------------

grant execute on function public.current_tenant_id() to anon, authenticated;
grant execute on function public.is_platform_admin() to anon, authenticated;
grant execute on function public.current_app_role() to anon, authenticated;
grant execute on function public.is_tenant_manager() to anon, authenticated;
grant execute on function public.is_tenant_actor() to anon, authenticated;

-- Normalización de slug (auth / subdominio)
grant execute on function public.tenant_slug_key(text) to anon, authenticated;

-- ---------------------------------------------------------------------
-- Re-grants: RPCs de producto (solo authenticated)
-- ---------------------------------------------------------------------

grant execute on function public.am_i_platform_admin() to authenticated;
grant execute on function public.provision_my_tenant(text) to authenticated;
grant execute on function public.slugify_tenant_name(text) to authenticated;
grant execute on function public.set_active_tenant(uuid) to authenticated;

grant execute on function public.list_tenant_members() to authenticated;
grant execute on function public.invite_user_to_tenant(text, text, text) to authenticated;
grant execute on function public.deactivate_tenant_member(uuid) to authenticated;

grant execute on function public.register_sale(jsonb, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.set_venta_pdf_path(uuid, text) to authenticated;
grant execute on function public.void_sale(uuid, text, text) to authenticated;
grant execute on function public.set_venta_facturada(uuid, boolean, text, text) to authenticated;
grant execute on function public.set_product_stock(text, integer, text, text) to authenticated;

grant execute on function public.list_ventas_for_range(timestamptz, timestamptz) to authenticated;
grant execute on function public.search_ventas_by_dni(text) to authenticated;
grant execute on function public.list_ventas_platform_metrics() to authenticated;

grant execute on function public.complete_seller_portal_login(text, text, text) to authenticated;
grant execute on function public.set_seller_portal_code(text) to authenticated;
grant execute on function public.current_tenant_slug() to authenticated;
grant execute on function public.list_tenants_with_seller_portal() to authenticated;

-- ---------------------------------------------------------------------
-- Service-role only (Edge Functions)
-- ---------------------------------------------------------------------

grant execute on function public.validate_seller_portal(text, text, text) to service_role;
grant execute on function public.touch_seller_portal_rate_limit(text, integer, integer) to service_role;

-- Auth hook: solo supabase_auth_admin (ya suele estar; reafirmar)
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;

-- ---------------------------------------------------------------------
-- Explicitamente SIN grant a clientes (documentación):
--   apply_product_stock_delta, hash_portal_code, verify_portal_code,
--   normalize_dni, _sale_*, require_tenant_*, set_tenant_id, trg_*
-- Esas quedan solo para owner / security definer / service_role según
-- grants residuales del owner.
-- ---------------------------------------------------------------------

commit;

notify pgrst, 'reload schema';
