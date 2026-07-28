-- 011_team_members.sql
-- Invitar usuarios (por email) a la armería activa + listar el equipo.
-- Requiere que la persona ya tenga cuenta en Supabase Auth.

create or replace function public.list_tenant_members()
returns table (
  user_id uuid,
  email text,
  nombre text,
  rol text,
  activo boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
begin
  if v_tenant is null then
    raise exception 'Sin armería activa en la sesión';
  end if;

  if not public.is_platform_admin()
     and not exists (
       select 1 from public.memberships m
        where m.user_id = auth.uid()
          and m.tenant_id = v_tenant
          and m.activo = true
     ) then
    raise exception 'Sin acceso al equipo de esta armería';
  end if;

  return query
    select m.user_id,
           u.email::text,
           m.nombre,
           m.rol,
           m.activo,
           m.created_at
      from public.memberships m
      join auth.users u on u.id = m.user_id
     where m.tenant_id = v_tenant
     order by m.created_at;
end;
$$;

create or replace function public.invite_user_to_tenant(
  p_email text,
  p_nombre text default '',
  p_rol text default 'admin'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_user_id uuid;
  v_rol text := lower(trim(coalesce(p_rol, 'admin')));
begin
  if v_tenant is null then
    raise exception 'Sin armería activa en la sesión';
  end if;

  if v_rol not in ('owner', 'admin') then
    raise exception 'Rol inválido';
  end if;

  if not public.is_platform_admin()
     and not exists (
       select 1 from public.memberships m
        where m.user_id = auth.uid()
          and m.tenant_id = v_tenant
          and m.rol = 'owner'
          and m.activo = true
     ) then
    raise exception 'Solo el dueño de la armería puede invitar personas';
  end if;

  select u.id
    into v_user_id
    from auth.users u
   where lower(u.email) = lower(trim(p_email))
   limit 1;

  if v_user_id is null then
    raise exception
      'No hay cuenta con ese email. La persona debe registrarse primero en la app.';
  end if;

  insert into public.memberships (user_id, tenant_id, rol, nombre, activo)
  values (
    v_user_id,
    v_tenant,
    v_rol,
    coalesce(nullif(trim(p_nombre), ''), split_part(trim(p_email), '@', 1)),
    true
  )
  on conflict (user_id, tenant_id) do update
    set rol = excluded.rol,
        nombre = excluded.nombre,
        activo = true;
end;
$$;

create or replace function public.deactivate_tenant_member(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
begin
  if v_tenant is null then
    raise exception 'Sin armería activa en la sesión';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'No podés desactivarte a vos mismo';
  end if;

  if not public.is_platform_admin()
     and not exists (
       select 1 from public.memberships m
        where m.user_id = auth.uid()
          and m.tenant_id = v_tenant
          and m.rol = 'owner'
          and m.activo = true
     ) then
    raise exception 'Solo el dueño puede quitar acceso';
  end if;

  update public.memberships
     set activo = false
   where user_id = p_user_id
     and tenant_id = v_tenant;
end;
$$;

revoke all on function public.list_tenant_members() from public;
revoke all on function public.invite_user_to_tenant(text, text, text) from public;
revoke all on function public.deactivate_tenant_member(uuid) from public;

grant execute on function public.list_tenant_members() to authenticated;
grant execute on function public.invite_user_to_tenant(text, text, text) to authenticated;
grant execute on function public.deactivate_tenant_member(uuid) to authenticated;

notify pgrst, 'reload schema';
