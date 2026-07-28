-- =====================================================================
-- Migracion 006 - Tenant "World Guns" (armeria de la feria)
-- =====================================================================
--
-- Crea el tenant world-guns y mueve los datos del tenant "default" a el.
-- Vincula al dueno existente (agustinfernandezbritos@gmail.com).
--
-- Ejecutar despues de 005.
-- =====================================================================

do $$
declare
  v_default uuid;
  v_world uuid;
  v_owner uuid;
begin
  select id into v_default from public.tenants where slug = 'default';

  insert into public.tenants (nombre, slug)
  values ('World Guns', 'world-guns')
  on conflict (slug) do update set nombre = excluded.nombre
  returning id into v_world;

  if v_world is null then
    select id into v_world from public.tenants where slug = 'world-guns';
  end if;

  if v_default is not null and v_default <> v_world then
    update public.productos          set tenant_id = v_world where tenant_id = v_default;
    update public.vendedores         set tenant_id = v_world where tenant_id = v_default;
    update public.administradores    set tenant_id = v_world where tenant_id = v_default;
    update public.stock_movimientos  set tenant_id = v_world where tenant_id = v_default;
    update public.audit_log          set tenant_id = v_world where tenant_id = v_default;
    update public.ventas             set tenant_id = v_world where tenant_id = v_default;
    update public.app_config         set tenant_id = v_world where tenant_id = v_default;

    update public.memberships
       set tenant_id = v_world
     where tenant_id = v_default;
  end if;

  select id into v_owner
  from auth.users
  where email = 'agustinfernandezbritos@gmail.com';

  if v_owner is not null then
    insert into public.memberships (user_id, tenant_id, rol, nombre)
    values (v_owner, v_world, 'owner', 'Agustín')
    on conflict (user_id, tenant_id) do update
      set rol = excluded.rol, nombre = excluded.nombre, activo = true;

    update auth.users
       set raw_app_meta_data =
         coalesce(raw_app_meta_data, '{}'::jsonb)
         || jsonb_build_object('active_tenant', v_world::text)
     where id = v_owner;
  end if;
end $$;
