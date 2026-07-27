-- =====================================================================
-- Migracion 003 - Cambio de tenant activo (multi-membresia)
-- =====================================================================
--
-- Permite que un mismo usuario pertenezca a varias armerias (y/o sea
-- platform admin) y elija en cada sesion a cual entrar:
--   - El "tenant activo" se guarda en auth.users.raw_app_meta_data.active_tenant.
--   - El access token hook mete ESE tenant en el claim tenant_id (validado
--     contra memberships: si no es miembro, cae a su primera membresia).
--   - Al cambiar de tenant, la app llama a la Edge Function `switch-tenant`
--     y luego refresca la sesion (nuevo JWT con el nuevo claim).
--
-- No requiere cambios en los repositorios: la RLS sigue siendo por claim.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor (despues de 001).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Hook: prioriza el tenant activo (app_metadata) si el usuario es miembro
-- ---------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  uid uuid;
  v_active uuid;
  v_tenant uuid;
  v_role text;
  v_is_platform boolean;
begin
  uid := (event->>'user_id')::uuid;

  -- Tenant activo elegido por el usuario (si existe).
  select nullif(u.raw_app_meta_data->>'active_tenant', '')::uuid
    into v_active
  from auth.users u
  where u.id = uid;

  -- Elige el tenant activo si el usuario es miembro; si no, su primera membresia.
  -- (Asi nunca se puede "entrar" a un tenant del que no se es miembro.)
  select m.tenant_id, m.rol
    into v_tenant, v_role
  from public.memberships m
  where m.user_id = uid
    and m.activo
  order by (m.tenant_id = v_active) desc nulls last, m.created_at
  limit 1;

  select exists (
    select 1 from public.platform_admins pa
    where pa.user_id = uid
  ) into v_is_platform;

  claims := coalesce(event->'claims', '{}'::jsonb);

  if v_tenant is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant::text));
    claims := jsonb_set(claims, '{app_role}', to_jsonb(coalesce(v_role, 'admin')));
  else
    -- Sin membresia activa: no exponemos tenant_id.
    claims := claims - 'tenant_id' - 'app_role';
  end if;
  claims := jsonb_set(claims, '{is_platform_admin}', to_jsonb(coalesce(v_is_platform, false)));

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;

-- ---------------------------------------------------------------------
-- 2. tenants_select: el usuario debe poder ver TODAS sus armerias
--    (para armar el selector), no solo la activa.
-- ---------------------------------------------------------------------

drop policy if exists "tenants_select" on public.tenants;
create policy "tenants_select" on public.tenants
  for select using (
    public.is_platform_admin()
    or id = public.current_tenant_id()
    or id in (
      select m.tenant_id from public.memberships m
      where m.user_id = auth.uid() and m.activo
    )
  );

-- ---------------------------------------------------------------------
-- 3. set_active_tenant: RPC seguro para cambiar de tenant activo.
--    Valida que el usuario sea miembro del tenant destino y actualiza
--    app_metadata. Devuelve true si se aplico. Alternativa a la Edge
--    Function (no requiere service-role desde el cliente).
-- ---------------------------------------------------------------------

create or replace function public.set_active_tenant(p_tenant uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  is_member boolean;
begin
  if uid is null then
    raise exception 'no authenticated user';
  end if;

  select exists (
    select 1 from public.memberships m
    where m.user_id = uid and m.tenant_id = p_tenant and m.activo
  ) into is_member;

  if not is_member then
    raise exception 'not a member of tenant %', p_tenant;
  end if;

  update auth.users
     set raw_app_meta_data =
       coalesce(raw_app_meta_data, '{}'::jsonb)
       || jsonb_build_object('active_tenant', p_tenant::text)
   where id = uid;

  return true;
end;
$$;

grant execute on function public.set_active_tenant(uuid) to authenticated;
