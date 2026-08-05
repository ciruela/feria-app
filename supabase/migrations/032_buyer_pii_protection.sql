-- =====================================================================
-- 032_buyer_pii_protection.sql
-- ---------------------------------------------------------------------
-- AR-14 (PII-002/003/004): datos del comprador.
--
-- 1) Lectura de ventas solo gestores (seller ya no hace SELECT libre).
-- 2) Sin SELECT directo PostgREST sobre ventas: listado y búsqueda DNI
--    pasan por RPC (el DNI viaja en el body, no en query string).
-- 3) search_ventas_by_dni deja rastro en audit_log (sufijo, no DNI completo).
-- 4) Inmutabilidad de cliente_* / items ya está en 026; se reafirma revoke.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Normalización DNI (solo dígitos)
-- ---------------------------------------------------------------------

create or replace function public.normalize_dni(p_dni text)
returns text
language sql
immutable
as $$
  select regexp_replace(coalesce(p_dni, ''), '[^0-9]', '', 'g');
$$;

revoke all on function public.normalize_dni(text) from public;
grant execute on function public.normalize_dni(text) to authenticated;

create index if not exists ventas_tenant_dni_norm_idx
  on public.ventas (tenant_id, (public.normalize_dni(cliente_dni)));

-- ---------------------------------------------------------------------
-- RLS: solo gestores leen ventas (defense in depth; grants abajo)
-- ---------------------------------------------------------------------

drop policy if exists "ventas_select" on public.ventas;

create policy "ventas_select" on public.ventas
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- Sin lectura directa vía PostgREST (evita filtro eq.cliente_dni en query string).
revoke select, insert, update, delete on public.ventas from authenticated, anon;

-- ---------------------------------------------------------------------
-- Listado operativo (comprobantes / métricas / cierre)
-- ---------------------------------------------------------------------

create or replace function public.list_ventas_for_range(
  p_from timestamptz,
  p_to timestamptz
)
returns setof public.ventas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  if p_from is null or p_to is null or p_to <= p_from then
    raise exception 'invalid_range'
      using errcode = '22023',
            hint = 'p_from / p_to deben definir un rango válido';
  end if;

  return query
    select v.*
    from public.ventas v
    where v.tenant_id = v_tenant
      and v.created_at >= p_from
      and v.created_at < p_to
    order by v.created_at;
end;
$$;

revoke all on function public.list_ventas_for_range(timestamptz, timestamptz) from public;
grant execute on function public.list_ventas_for_range(timestamptz, timestamptz) to authenticated;

-- ---------------------------------------------------------------------
-- Búsqueda por DNI con auditoría (body RPC, no query string)
-- ---------------------------------------------------------------------

create or replace function public.search_ventas_by_dni(p_dni text)
returns setof public.ventas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_norm text := public.normalize_dni(p_dni);
  v_suffix text;
  v_count int := 0;
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  if length(v_norm) < 6 then
    raise exception 'invalid_dni'
      using errcode = '22023',
            hint = 'DNI inválido para búsqueda';
  end if;

  v_suffix := right(v_norm, 4);

  select count(*)::int into v_count
  from public.ventas v
  where v.tenant_id = v_tenant
    and public.normalize_dni(v.cliente_dni) = v_norm;

  insert into public.audit_log (
    tenant_id,
    actor_nombre,
    accion,
    entidad,
    entidad_id,
    detalle
  ) values (
    v_tenant,
    coalesce(auth.jwt()->>'email', auth.uid()::text, 'gestor'),
    'Consultó comprador por DNI',
    'venta',
    '',
    format('sufijo %s · %s coincidencia(s)', v_suffix, v_count)
  );

  return query
    select v.*
    from public.ventas v
    where v.tenant_id = v_tenant
      and public.normalize_dni(v.cliente_dni) = v_norm
    order by v.created_at desc;
end;
$$;

revoke all on function public.search_ventas_by_dni(text) from public;
grant execute on function public.search_ventas_by_dni(text) to authenticated;

-- ---------------------------------------------------------------------
-- Fallback panel platform (sin SELECT PostgREST sobre ventas)
-- ---------------------------------------------------------------------

create or replace function public.list_ventas_platform_metrics()
returns table (
  tenant_id uuid,
  total_ars numeric,
  total_usd numeric,
  anulada boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'forbidden_role'
      using errcode = '42501',
            hint = 'Solo platform admin';
  end if;

  return query
    select v.tenant_id, v.total_ars, v.total_usd, coalesce(v.anulada, false)
    from public.ventas v;
end;
$$;

revoke all on function public.list_ventas_platform_metrics() from public;
grant execute on function public.list_ventas_platform_metrics() to authenticated;

commit;

notify pgrst, 'reload schema';
