-- 043_remove_tenant_member.sql
-- Eliminar persona del equipo (membership DELETE).
-- Owner y admin pueden quitar admins; solo owner puede quitar owners.

create or replace function public.deactivate_tenant_member(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_caller_rol text;
  v_target_rol text;
  v_owner_count int;
begin
  if v_tenant is null then
    raise exception 'Sin armería activa en la sesión';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'No podés desactivarte a vos mismo';
  end if;

  if public.is_platform_admin() then
    v_caller_rol := 'owner';
  else
    select m.rol
      into v_caller_rol
      from public.memberships m
     where m.user_id = auth.uid()
       and m.tenant_id = v_tenant
       and m.activo = true;

    if v_caller_rol is null then
      raise exception 'Sin acceso al equipo de esta armería';
    end if;

    if v_caller_rol not in ('owner', 'admin') then
      raise exception 'Solo dueño o administrador pueden quitar personas del equipo';
    end if;
  end if;

  select m.rol
    into v_target_rol
    from public.memberships m
   where m.user_id = p_user_id
     and m.tenant_id = v_tenant
     and m.activo = true;

  if v_target_rol is null then
    raise exception 'Esa persona no está en el equipo';
  end if;

  if v_target_rol = 'owner' and v_caller_rol <> 'owner' then
    raise exception 'Solo el dueño puede quitar a otro dueño';
  end if;

  if v_target_rol = 'owner' then
    select count(*)::int
      into v_owner_count
      from public.memberships m
     where m.tenant_id = v_tenant
       and m.rol = 'owner'
       and m.activo = true;

    if v_owner_count <= 1 then
      raise exception 'No podés eliminar al único dueño de la armería';
    end if;
  end if;

  update public.memberships
     set activo = false
   where user_id = p_user_id
     and tenant_id = v_tenant;
end;
$$;

create or replace function public.remove_tenant_member(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_caller uuid := auth.uid();
  v_caller_rol text;
  v_target_rol text;
  v_owner_count int;
begin
  if v_tenant is null then
    raise exception 'Sin armería activa en la sesión';
  end if;

  if v_caller is null then
    raise exception 'No autorizado';
  end if;

  if p_user_id = v_caller then
    raise exception 'No podés eliminarte a vos mismo del equipo';
  end if;

  if public.is_platform_admin() then
    v_caller_rol := 'owner';
  else
    select m.rol
      into v_caller_rol
      from public.memberships m
     where m.user_id = v_caller
       and m.tenant_id = v_tenant
       and m.activo = true;

    if v_caller_rol is null then
      raise exception 'Sin acceso al equipo de esta armería';
    end if;

    if v_caller_rol not in ('owner', 'admin') then
      raise exception 'Solo dueño o administrador pueden quitar personas del equipo';
    end if;
  end if;

  select m.rol
    into v_target_rol
    from public.memberships m
   where m.user_id = p_user_id
     and m.tenant_id = v_tenant;

  if v_target_rol is null then
    raise exception 'Esa persona no está en el equipo';
  end if;

  if v_target_rol = 'owner' and v_caller_rol <> 'owner' then
    raise exception 'Solo el dueño puede quitar a otro dueño';
  end if;

  if v_target_rol = 'owner' then
    select count(*)::int
      into v_owner_count
      from public.memberships m
     where m.tenant_id = v_tenant
       and m.rol = 'owner'
       and m.activo = true;

    if v_owner_count <= 1 then
      raise exception 'No podés eliminar al único dueño de la armería';
    end if;
  end if;

  delete from public.memberships
   where user_id = p_user_id
     and tenant_id = v_tenant;
end;
$$;

revoke all on function public.deactivate_tenant_member(uuid) from public;
grant execute on function public.deactivate_tenant_member(uuid) to authenticated;

revoke all on function public.remove_tenant_member(uuid) from public;
grant execute on function public.remove_tenant_member(uuid) to authenticated;

notify pgrst, 'reload schema';
