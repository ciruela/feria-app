-- =====================================================================
-- Migracion 008 - Guard de provision: solo crear tenant con intencion explicita
-- =====================================================================
--
-- Evita que provision_my_tenant cree una organizacion para cuentas que solo
-- iniciaron sesion sin membership. Requiere user_metadata.registration_intent
-- = 'create_organization' (seteado en signUp del flujo "Registrar mi armeria").
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor (despues de 005-007).
-- =====================================================================

create or replace function public.provision_my_tenant(p_nombre text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_email text;
  v_meta jsonb;
  v_nombre text;
  v_slug text;
  v_slug_base text;
  v_suffix int := 0;
  v_tenant uuid;
  v_display text;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select email, raw_user_meta_data
    into v_email, v_meta
  from auth.users
  where id = uid;

  if not exists (
    select 1 from auth.users
    where id = uid and email_confirmed_at is not null
  ) then
    raise exception 'email not confirmed';
  end if;

  -- Ya tiene armeria: devuelve la primera membresia activa y limpia intent stale.
  select m.tenant_id into v_tenant
  from public.memberships m
  where m.user_id = uid and m.activo
  order by m.created_at
  limit 1;

  if v_tenant is not null then
    update auth.users
       set raw_app_meta_data =
             coalesce(raw_app_meta_data, '{}'::jsonb)
             || jsonb_build_object('active_tenant', v_tenant::text),
           raw_user_meta_data =
             coalesce(raw_user_meta_data, '{}'::jsonb) - 'registration_intent'
     where id = uid;
    return v_tenant;
  end if;

  -- Sin membership: solo provisionar si el registro fue "Registrar mi armeria".
  if coalesce(v_meta->>'registration_intent', '') <> 'create_organization' then
    raise exception 'organization registration not requested';
  end if;

  v_nombre := nullif(trim(p_nombre), '');
  if v_nombre is null then
    v_nombre := nullif(trim(v_meta->>'company_name'), '');
  end if;
  if v_nombre is null then
    v_nombre := 'Mi Armería';
  end if;

  v_slug_base := public.slugify_tenant_name(v_nombre);
  v_slug := v_slug_base;

  while exists (select 1 from public.tenants t where t.slug = v_slug) loop
    v_suffix := v_suffix + 1;
    v_slug := v_slug_base || '-' || v_suffix::text;
  end loop;

  insert into public.tenants (nombre, slug)
  values (v_nombre, v_slug)
  returning id into v_tenant;

  v_display := coalesce(
    nullif(trim(v_meta->>'full_name'), ''),
    split_part(coalesce(v_email, ''), '@', 1),
    'Dueño'
  );

  insert into public.memberships (user_id, tenant_id, rol, nombre)
  values (uid, v_tenant, 'owner', v_display);

  update auth.users
     set raw_app_meta_data =
           coalesce(raw_app_meta_data, '{}'::jsonb)
           || jsonb_build_object('active_tenant', v_tenant::text),
         raw_user_meta_data =
           (coalesce(raw_user_meta_data, '{}'::jsonb) - 'registration_intent')
     where id = uid;

  return v_tenant;
end;
$$;

grant execute on function public.provision_my_tenant(text) to authenticated;
