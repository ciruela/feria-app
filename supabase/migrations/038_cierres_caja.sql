-- =====================================================================
-- 038_cierres_caja.sql
-- ---------------------------------------------------------------------
-- AR-22: el cierre de caja no se persiste; se recalcula cada vez desde
--        fuentes vivas, así que el cierre de un día pasado cambia con
--        ellas. Se convierte en una ENTIDAD PERSISTIDA (asiento):
--        - totales congelados + hash de las filas que lo componen
--        - quién y cuándo cerró
--        - una vez cerrado un día, se bloquean escrituras retroactivas
--          sobre ventas / stock_movimientos con fecha <= último cierre
--        - reapertura solo explícita, registrada y con motivo
-- Depende de AR-6/AR-7 (fuentes ya inmutables/trazables) — ya aplicados.
-- =====================================================================

begin;

create table if not exists public.cierres_caja (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  fecha date not null,
  total_ventas_ars numeric not null default 0,
  total_ventas_usd numeric not null default 0,
  cantidad_ventas integer not null default 0,
  rows_hash text not null default '',
  cerrado_por text not null default '',
  cerrado_at timestamptz not null default now(),
  reabierto boolean not null default false,
  reabierto_motivo text not null default '',
  reabierto_por text not null default '',
  reabierto_at timestamptz
);

-- Un solo cierre ACTIVO por (tenant, fecha); reaperturas conviven como histórico.
create unique index if not exists cierres_caja_activo_uidx
  on public.cierres_caja (tenant_id, fecha)
  where reabierto = false;

create index if not exists cierres_caja_tenant_fecha_idx
  on public.cierres_caja (tenant_id, fecha desc);

alter table public.cierres_caja enable row level security;

drop policy if exists cierres_caja_select on public.cierres_caja;
create policy cierres_caja_select on public.cierres_caja
  for select to authenticated
  using (
    public.is_platform_admin()
    or tenant_id = public.current_tenant_id()
  );

-- Escritura solo por RPC SECURITY DEFINER (no PostgREST directo).
revoke insert, update, delete on public.cierres_caja from anon, authenticated;

-- ---------------------------------------------------------------------
-- Fecha del último cierre activo de un tenant (o null).
-- ---------------------------------------------------------------------
create or replace function public.ultimo_cierre_fecha(p_tenant uuid)
returns date
language sql
stable
as $$
  select max(fecha)
  from public.cierres_caja
  where tenant_id = p_tenant and reabierto = false;
$$;

-- ---------------------------------------------------------------------
-- Guard: no permitir escrituras retroactivas sobre ventas /
-- stock_movimientos en un período ya cerrado.
-- ---------------------------------------------------------------------
create or replace function public.trg_bloquear_periodo_cerrado()
returns trigger
language plpgsql
as $$
declare
  v_tenant uuid;
  v_fecha date;
  v_cierre date;
begin
  if tg_op = 'DELETE' then
    v_tenant := old.tenant_id;
    v_fecha := (old.created_at)::date;
  else
    v_tenant := coalesce(new.tenant_id, old.tenant_id);
    v_fecha := (coalesce(new.created_at, old.created_at))::date;
  end if;

  if v_tenant is null then
    return coalesce(new, old);
  end if;

  v_cierre := public.ultimo_cierre_fecha(v_tenant);
  if v_cierre is not null and v_fecha <= v_cierre then
    raise exception 'periodo_cerrado'
      using errcode = '42501',
            hint = 'El día ya tiene cierre de caja; reabrí el cierre para modificarlo.';
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_ventas_periodo_cerrado on public.ventas;
create trigger trg_ventas_periodo_cerrado
  before insert or update or delete on public.ventas
  for each row execute function public.trg_bloquear_periodo_cerrado();

drop trigger if exists trg_stockmov_periodo_cerrado on public.stock_movimientos;
create trigger trg_stockmov_periodo_cerrado
  before insert or update or delete on public.stock_movimientos
  for each row execute function public.trg_bloquear_periodo_cerrado();

-- ---------------------------------------------------------------------
-- Registrar cierre: congela totales + hash de las ventas del día.
-- ---------------------------------------------------------------------
create or replace function public.registrar_cierre_caja(p_fecha date)
returns public.cierres_caja
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_row public.cierres_caja;
  v_hash text;
  v_total_ars numeric;
  v_total_usd numeric;
  v_count integer;
begin
  perform public.require_tenant_manager();

  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;

  if exists (
    select 1 from public.cierres_caja
    where tenant_id = v_tenant and fecha = p_fecha and reabierto = false
  ) then
    raise exception 'cierre_ya_existe'
      using errcode = 'P0001', hint = 'Ya hay un cierre activo para ese día.';
  end if;

  select
    coalesce(sum(total_ars), 0),
    coalesce(sum(total_usd), 0),
    count(*),
    coalesce(
      md5(string_agg(
        id::text || ':' || coalesce(total_ars, 0)::text || ':' ||
        coalesce(total_usd, 0)::text,
        '|' order by id
      )),
      ''
    )
  into v_total_ars, v_total_usd, v_count, v_hash
  from public.ventas
  where tenant_id = v_tenant
    and (created_at)::date = p_fecha
    and anulada = false;

  insert into public.cierres_caja (
    tenant_id, fecha, total_ventas_ars, total_ventas_usd,
    cantidad_ventas, rows_hash, cerrado_por
  ) values (
    v_tenant, p_fecha, v_total_ars, v_total_usd,
    v_count, v_hash, coalesce(auth.uid()::text, '')
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- Reabrir un cierre: operación explícita, registrada y con motivo.
-- ---------------------------------------------------------------------
create or replace function public.reabrir_cierre_caja(p_id uuid, p_motivo text)
returns public.cierres_caja
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_row public.cierres_caja;
begin
  perform public.require_tenant_manager();
  v_tenant := public.current_tenant_id();

  if coalesce(trim(p_motivo), '') = '' then
    raise exception 'motivo_requerido'
      using errcode = 'P0001', hint = 'La reapertura requiere un motivo.';
  end if;

  update public.cierres_caja
     set reabierto = true,
         reabierto_motivo = p_motivo,
         reabierto_por = coalesce(auth.uid()::text, ''),
         reabierto_at = now()
   where id = p_id
     and (tenant_id = v_tenant or public.is_platform_admin())
     and reabierto = false
  returning * into v_row;

  if v_row.id is null then
    raise exception 'cierre_no_encontrado' using errcode = 'P0002';
  end if;

  return v_row;
end;
$$;

revoke all on function public.registrar_cierre_caja(date) from public, anon;
revoke all on function public.reabrir_cierre_caja(uuid, text) from public, anon;
grant execute on function public.registrar_cierre_caja(date) to authenticated;
grant execute on function public.reabrir_cierre_caja(uuid, text) to authenticated;

commit;
