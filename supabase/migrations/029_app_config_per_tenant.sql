-- =====================================================================
-- 029_app_config_per_tenant.sql
-- ---------------------------------------------------------------------
-- AR-11 / SQL-001: app_config.id='global' era PK global; solo un tenant
-- podía guardar tipo de cambio. PK pasa a (tenant_id, id) y cada armería
-- tiene su fila. provision_my_tenant siembra app_config al crear tenant.
-- =====================================================================

begin;

-- Valor de referencia (fila legacy) para sembrar tenants sin config.
do $$
declare
  v_seed_rate numeric;
begin
  select exchange_rate_ars
    into v_seed_rate
    from public.app_config
   where id = 'global'
   order by case when tenant_id is null then 1 else 0 end, updated_at desc nulls last
   limit 1;

  v_seed_rate := coalesce(nullif(v_seed_rate, 0), 1500);

  insert into public.app_config (id, tenant_id, exchange_rate_ars, updated_at)
  select
    'global',
    t.id,
    v_seed_rate,
    timezone('utc', now())
  from public.tenants t
  where not exists (
    select 1
      from public.app_config c
     where c.id = 'global'
       and c.tenant_id = t.id
  );
end $$;

-- Filas sin tenant ya no son válidas (tras el seed por tenant).
delete from public.app_config where tenant_id is null;

alter table public.app_config
  alter column tenant_id set not null;

-- Recrear PK compuesta.
alter table public.app_config drop constraint if exists app_config_pkey;
alter table public.app_config
  add constraint app_config_pkey primary key (tenant_id, id);

create index if not exists app_config_tenant_idx
  on public.app_config (tenant_id);

-- Siembra al provisionar una armería nueva.
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
    -- Backfill por si el tenant es anterior a esta migración.
    insert into public.app_config (id, tenant_id, exchange_rate_ars, updated_at)
    values ('global', v_tenant, 1500, timezone('utc', now()))
    on conflict (tenant_id, id) do nothing;
    return v_tenant;
  end if;

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

  insert into public.app_config (id, tenant_id, exchange_rate_ars, updated_at)
  values ('global', v_tenant, 1500, timezone('utc', now()))
  on conflict (tenant_id, id) do nothing;

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

commit;

notify pgrst, 'reload schema';
