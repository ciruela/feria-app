-- =====================================================================
-- 022_tenant_slug_subdomain_match.sql
-- ---------------------------------------------------------------------
-- Permite acceder al portal de vendedores con subdominios sin guiones:
--   urbantactical.armenext.com  -> slug urban-tactical
--   worldguns.armenext.com      -> slug world-guns
-- =====================================================================

begin;

create or replace function public.tenant_slug_key(p_slug text)
returns text
language sql
immutable
parallel safe
as $$
  select replace(lower(trim(coalesce(p_slug, ''))), '-', '');
$$;

create or replace function public.validate_seller_portal(
  p_slug text,
  p_codigo text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant record;
  v_sellers jsonb;
  v_hash text := public.hash_portal_code(p_codigo);
begin
  select t.id, t.nombre, t.slug, t.codigo_vendedores
    into v_tenant
    from public.tenants t
   where public.tenant_slug_key(t.slug) = public.tenant_slug_key(p_slug)
     and t.activo
   limit 1;

  if v_tenant.id is null
     or coalesce(v_tenant.codigo_vendedores, '') = ''
     or v_hash <> v_tenant.codigo_vendedores then
    raise exception 'Dominio o clave incorrectos';
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object('id', v.id, 'nombre', v.nombre)
             order by v.nombre
           ),
           '[]'::jsonb
         )
    into v_sellers
    from public.vendedores v
   where v.tenant_id = v_tenant.id
     and v.activo;

  if v_sellers = '[]'::jsonb then
    raise exception 'No hay vendedores activos en esta armería';
  end if;

  return jsonb_build_object(
    'tenant_id', v_tenant.id,
    'tenant_nombre', v_tenant.nombre,
    'tenant_slug', v_tenant.slug,
    'sellers', v_sellers
  );
end;
$$;

grant execute on function public.tenant_slug_key(text) to authenticated, anon;
grant execute on function public.validate_seller_portal(text, text) to anon, authenticated;

notify pgrst, 'reload schema';

commit;
