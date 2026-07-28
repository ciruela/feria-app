-- 012_seller_portal.sql
-- Portal de vendedores: dominio (slug) + clave, sin registro en Supabase.
--
-- Requisito en Dashboard: Authentication → Providers → Anonymous sign-ins → ON
--
-- Flujo:
--   1) validate_seller_portal(slug, clave) → lista de vendedores (anon OK)
--   2) signInAnonymously() en la app
--   3) complete_seller_portal_login(slug, clave, seller_id) → JWT con tenant_id + seller

create extension if not exists pgcrypto with schema extensions;

alter table public.tenants
  add column if not exists codigo_vendedores text not null default '';

create or replace function public.hash_portal_code(p_code text)
returns text
language sql
immutable
parallel safe
as $$
  select encode(
    extensions.digest(
      'feria-armeria::portal::v1' || trim(p_code),
      'sha256'
    ),
    'hex'
  );
$$;

-- Valida dominio + clave y devuelve vendedores activos (sin auth).
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
begin
  select t.id, t.nombre, t.slug, t.codigo_vendedores
    into v_tenant
    from public.tenants t
   where lower(trim(t.slug)) = lower(trim(p_slug))
     and t.activo
   limit 1;

  if v_tenant.id is null then
    raise exception 'No encontramos una armería con ese dominio';
  end if;

  if v_tenant.codigo_vendedores = ''
     or v_tenant.codigo_vendedores is null then
    raise exception 'Esta armería todavía no configuró el código de vendedores';
  end if;

  if public.hash_portal_code(p_codigo) <> v_tenant.codigo_vendedores then
    raise exception 'Clave incorrecta';
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

-- Establece sesión de vendedor en auth.users (requiere usuario autenticado, ej. anon).
create or replace function public.complete_seller_portal_login(
  p_slug text,
  p_codigo text,
  p_seller_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_payload jsonb;
  v_tenant_id uuid;
  v_seller_nombre text;
begin
  if uid is null then
    raise exception 'Sesión no iniciada';
  end if;

  v_payload := public.validate_seller_portal(p_slug, p_codigo);
  v_tenant_id := (v_payload->>'tenant_id')::uuid;

  select v.nombre
    into v_seller_nombre
    from public.vendedores v
   where v.id = trim(p_seller_id)
     and v.tenant_id = v_tenant_id
     and v.activo
   limit 1;

  if v_seller_nombre is null then
    raise exception 'Vendedor no válido';
  end if;

  update auth.users
     set raw_app_meta_data =
       coalesce(raw_app_meta_data, '{}'::jsonb)
       || jsonb_build_object(
            'active_tenant', v_tenant_id::text,
            'seller_tenant', v_tenant_id::text,
            'seller_id', trim(p_seller_id),
            'seller_nombre', v_seller_nombre,
            'seller_slug', v_payload->>'tenant_slug'
          )
   where id = uid;

  return jsonb_build_object(
    'tenant_id', v_tenant_id,
    'tenant_nombre', v_payload->>'tenant_nombre',
    'seller_id', trim(p_seller_id),
    'seller_nombre', v_seller_nombre
  );
end;
$$;

-- Dueño/admin configura el código de acceso de vendedores.
create or replace function public.set_seller_portal_code(p_codigo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
begin
  if v_tenant is null then
    raise exception 'Sin armería activa';
  end if;

  if trim(coalesce(p_codigo, '')) = '' then
    raise exception 'El código no puede estar vacío';
  end if;

  if length(trim(p_codigo)) < 4 then
    raise exception 'Usá al menos 4 caracteres';
  end if;

  if not public.is_platform_admin()
     and not exists (
       select 1 from public.memberships m
        where m.user_id = auth.uid()
          and m.tenant_id = v_tenant
          and m.rol in ('owner', 'admin')
          and m.activo
     ) then
    raise exception 'Sin permiso para cambiar el código';
  end if;

  update public.tenants
     set codigo_vendedores = public.hash_portal_code(p_codigo)
   where id = v_tenant;
end;
$$;

-- Slug del tenant activo (para mostrar al admin).
create or replace function public.current_tenant_slug()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select t.slug
    from public.tenants t
   where t.id = public.current_tenant_id()
   limit 1;
$$;

-- Hook: membresía email O sesión portal vendedor (anon).
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  uid uuid;
  v_active uuid;
  v_tenant uuid;
  v_role text;
  v_is_platform boolean;
  v_seller_tenant uuid;
  v_seller_id text;
  v_meta jsonb;
begin
  uid := (event->>'user_id')::uuid;

  select u.raw_app_meta_data into v_meta
    from auth.users u
   where u.id = uid;

  select nullif(v_meta->>'active_tenant', '')::uuid into v_active;

  select m.tenant_id, m.rol
    into v_tenant, v_role
    from public.memberships m
   where m.user_id = uid
     and m.activo
   order by (m.tenant_id = v_active) desc nulls last, m.created_at
   limit 1;

  select exists (
    select 1 from public.platform_admins pa where pa.user_id = uid
  ) into v_is_platform;

  if v_tenant is null then
    v_seller_tenant := nullif(v_meta->>'seller_tenant', '')::uuid;
    v_seller_id := nullif(trim(v_meta->>'seller_id'), '');

    if v_seller_tenant is not null and v_seller_id is not null then
      if exists (
        select 1 from public.vendedores v
         where v.id = v_seller_id
           and v.tenant_id = v_seller_tenant
           and v.activo
      ) then
        v_tenant := v_seller_tenant;
        v_role := 'seller';
      end if;
    end if;
  end if;

  claims := coalesce(event->'claims', '{}'::jsonb);

  if v_tenant is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant::text));
    claims := jsonb_set(claims, '{app_role}', to_jsonb(coalesce(v_role, 'admin')));
    if v_role = 'seller' and v_seller_id is not null then
      claims := jsonb_set(claims, '{seller_id}', to_jsonb(v_seller_id));
      if v_meta->>'seller_nombre' is not null then
        claims := jsonb_set(claims, '{seller_nombre}', v_meta->'seller_nombre');
      end if;
    else
      claims := claims - 'seller_id' - 'seller_nombre';
    end if;
  else
    claims := claims - 'tenant_id' - 'app_role' - 'seller_id' - 'seller_nombre';
  end if;

  claims := jsonb_set(claims, '{is_platform_admin}', to_jsonb(coalesce(v_is_platform, false)));

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

revoke all on function public.validate_seller_portal(text, text) from public;
revoke all on function public.complete_seller_portal_login(text, text, text) from public;
revoke all on function public.set_seller_portal_code(text) from public;
revoke all on function public.current_tenant_slug() from public;

grant execute on function public.validate_seller_portal(text, text) to anon, authenticated;
grant execute on function public.complete_seller_portal_login(text, text, text) to authenticated;
grant execute on function public.set_seller_portal_code(text) to authenticated;
grant execute on function public.current_tenant_slug() to authenticated;

grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;

notify pgrst, 'reload schema';
