-- =====================================================================
-- 033_seller_portal_auth.sql
-- ---------------------------------------------------------------------
-- AR-15 (AUTH-004 / API-002): portal de vendedores.
--
-- 1) Verificar/rotar: invalida hashes SHA-256 legacy (fuerza reconfiguración).
-- 2) bcrypt (pgcrypto) + código ≥ 10 chars alfanuméricos.
-- 3) Revoke select (codigo_vendedores); cierra oráculo hash_portal_code.
-- 4) validate solo service_role (Edge POST); rate limit por slug + bucket IP.
-- 5) AR-9 ya restringe el rol seller en el backend.
-- =====================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Rate limit persistente (Edge aporta bucket IP; SQL limita por slug)
-- ---------------------------------------------------------------------

create table if not exists public.seller_portal_rate_limits (
  bucket text primary key,
  hits integer not null default 0,
  window_start timestamptz not null default timezone('utc', now()),
  blocked_until timestamptz
);

alter table public.seller_portal_rate_limits enable row level security;

revoke all on public.seller_portal_rate_limits from public, anon, authenticated;

create or replace function public.touch_seller_portal_rate_limit(
  p_bucket text,
  p_limit integer default 20,
  p_window_seconds integer default 900
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_row public.seller_portal_rate_limits%rowtype;
  v_limit int := greatest(coalesce(p_limit, 20), 1);
  v_window int := greatest(coalesce(p_window_seconds, 900), 60);
  v_bucket text := left(trim(coalesce(p_bucket, '')), 200);
begin
  if v_bucket = '' then
    return jsonb_build_object('allowed', false, 'retry_after', v_window);
  end if;

  insert into public.seller_portal_rate_limits as r (bucket, hits, window_start)
  values (v_bucket, 0, v_now)
  on conflict (bucket) do nothing;

  select * into v_row
  from public.seller_portal_rate_limits
  where bucket = v_bucket
  for update;

  if v_row.blocked_until is not null and v_row.blocked_until > v_now then
    return jsonb_build_object(
      'allowed', false,
      'retry_after', greatest(1, extract(epoch from (v_row.blocked_until - v_now))::int)
    );
  end if;

  if v_row.window_start + make_interval(secs => v_window) <= v_now then
    update public.seller_portal_rate_limits
       set hits = 1,
           window_start = v_now,
           blocked_until = null
     where bucket = v_bucket;
    return jsonb_build_object('allowed', true, 'retry_after', 0);
  end if;

  if v_row.hits + 1 > v_limit then
    update public.seller_portal_rate_limits
       set hits = v_row.hits + 1,
           blocked_until = v_now + make_interval(secs => v_window)
     where bucket = v_bucket;
    return jsonb_build_object('allowed', false, 'retry_after', v_window);
  end if;

  update public.seller_portal_rate_limits
     set hits = v_row.hits + 1
   where bucket = v_bucket;

  return jsonb_build_object('allowed', true, 'retry_after', 0);
end;
$$;

revoke all on function public.touch_seller_portal_rate_limit(text, integer, integer) from public;
-- Solo service_role / owner (Edge). No anon/authenticated.
grant execute on function public.touch_seller_portal_rate_limit(text, integer, integer)
  to service_role;

-- ---------------------------------------------------------------------
-- Verificación de código: bcrypt nuevo + SHA-256 legacy (solo lectura)
-- ---------------------------------------------------------------------

create or replace function public.verify_portal_code(p_code text, p_stored text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_code text := trim(coalesce(p_code, ''));
  v_stored text := coalesce(p_stored, '');
begin
  if v_code = '' or v_stored = '' then
    return false;
  end if;

  -- bcrypt / xdes de pgcrypto
  if v_stored like '$%' then
    return extensions.crypt(v_code, v_stored) = v_stored;
  end if;

  -- Legacy SHA-256 hex (se invalida en el UPDATE de abajo; queda por defensa)
  return encode(
    extensions.digest('feria-armeria::portal::v1' || v_code, 'sha256'),
    'hex'
  ) = v_stored;
end;
$$;

revoke all on function public.verify_portal_code(text, text) from public;
-- Uso interno (security definer callers). Sin grant a clientes.

create or replace function public.hash_portal_code(p_code text)
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  -- Solo para migraciones internas / set; ya no es oráculo anónimo.
  select extensions.crypt(
    trim(p_code),
    extensions.gen_salt('bf', 10)
  );
$$;

revoke all on function public.hash_portal_code(text) from public;
revoke all on function public.hash_portal_code(text) from anon, authenticated;

-- ---------------------------------------------------------------------
-- Incidente: rotar códigos débiles (SHA-256 de 4 chars)
-- ---------------------------------------------------------------------

update public.tenants
   set codigo_vendedores = ''
 where codigo_vendedores ~ '^[0-9a-f]{64}$'
    or length(codigo_vendedores) = 64;

-- ---------------------------------------------------------------------
-- Ocultar hash a clientes (PostgREST select=*)
-- ---------------------------------------------------------------------

revoke select (codigo_vendedores) on public.tenants from anon, authenticated;

-- ---------------------------------------------------------------------
-- validate / complete con rate limit por slug + bcrypt
-- ---------------------------------------------------------------------

drop function if exists public.validate_seller_portal(text, text);

create or replace function public.validate_seller_portal(
  p_slug text,
  p_codigo text,
  p_client_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant record;
  v_sellers jsonb;
  v_slug text := lower(trim(coalesce(p_slug, '')));
  v_rate jsonb;
  v_ok boolean := false;
begin
  -- Rate limit por slug (cubre brute force vía complete sin Edge).
  v_rate := public.touch_seller_portal_rate_limit(
    'slug:' || v_slug,
    30,
    900
  );
  if coalesce((v_rate->>'allowed')::boolean, false) is not true then
    raise exception 'Demasiados intentos. Proba mas tarde.'
      using errcode = 'P0001';
  end if;

  if p_client_key is not null and trim(p_client_key) <> '' then
    v_rate := public.touch_seller_portal_rate_limit(
      'slugip:' || v_slug || ':' || left(trim(p_client_key), 120),
      15,
      900
    );
    if coalesce((v_rate->>'allowed')::boolean, false) is not true then
      raise exception 'Demasiados intentos. Proba mas tarde.'
        using errcode = 'P0001';
    end if;
  end if;

  select t.id, t.nombre, t.slug, t.codigo_vendedores
    into v_tenant
    from public.tenants t
   where lower(trim(t.slug)) = v_slug
     and t.activo
   limit 1;

  if v_tenant.id is not null and coalesce(v_tenant.codigo_vendedores, '') <> '' then
    v_ok := public.verify_portal_code(p_codigo, v_tenant.codigo_vendedores);
  end if;

  if not v_ok then
    raise exception 'Dominio o clave incorrectos';
  end if;

  -- Éxito: reset de buckets de este intento.
  update public.seller_portal_rate_limits
     set hits = 0, blocked_until = null, window_start = timezone('utc', now())
   where bucket = 'slug:' || v_slug
      or (
        p_client_key is not null
        and trim(p_client_key) <> ''
        and bucket = 'slugip:' || v_slug || ':' || left(trim(p_client_key), 120)
      );

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

create or replace function public.set_seller_portal_code(p_codigo text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_code text := trim(coalesce(p_codigo, ''));
begin
  if v_tenant is null then
    raise exception 'Sin armería activa';
  end if;

  perform public.require_tenant_manager();

  if v_code = '' then
    raise exception 'El código no puede estar vacío';
  end if;

  if length(v_code) < 10 then
    raise exception 'Usá al menos 10 caracteres';
  end if;

  if v_code !~ '^[A-Za-z0-9]+$' then
    raise exception 'Usá solo letras y números';
  end if;

  update public.tenants
     set codigo_vendedores = extensions.crypt(v_code, extensions.gen_salt('bf', 10))
   where id = v_tenant;
end;
$$;

-- Grants: validate solo service_role (Edge). complete para sesión anon autenticada.
revoke all on function public.validate_seller_portal(text, text, text) from public;
revoke all on function public.validate_seller_portal(text, text, text) from anon, authenticated;
grant execute on function public.validate_seller_portal(text, text, text) to service_role;

revoke all on function public.complete_seller_portal_login(text, text, text) from public;
revoke all on function public.complete_seller_portal_login(text, text, text) from anon;
grant execute on function public.complete_seller_portal_login(text, text, text) to authenticated;

revoke all on function public.set_seller_portal_code(text) from public;
grant execute on function public.set_seller_portal_code(text) to authenticated;

-- Verificación ops (platform): tenants con portal configurado
create or replace function public.list_tenants_with_seller_portal()
returns table (id uuid, slug text, nombre text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'forbidden_role' using errcode = '42501';
  end if;
  return query
    select t.id, t.slug, t.nombre
    from public.tenants t
   where coalesce(t.codigo_vendedores, '') <> ''
   order by t.slug;
end;
$$;

revoke all on function public.list_tenants_with_seller_portal() from public;
grant execute on function public.list_tenants_with_seller_portal() to authenticated;

commit;

notify pgrst, 'reload schema';
