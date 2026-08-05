-- =====================================================================
-- 025_immutable_audit_trail.sql
-- ---------------------------------------------------------------------
-- AR-7 (CONC-005 / SQL-002 / SQL-003): el rastro de inventario y la
-- auditoría no pueden editarse ni borrarse por quien los genera.
--
-- 1) Policies por operación (SELECT / INSERT) en lugar de FOR ALL.
-- 2) revoke update/delete; stock_movimientos sin insert cliente (ya en 024).
-- 3) audit_log: actor_id + created_at los fija el servidor.
-- 4) updated_at de detección + triggers que rechazan UPDATE/DELETE.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Columnas de detección
-- ---------------------------------------------------------------------

alter table public.stock_movimientos
  add column if not exists updated_at timestamptz;

alter table public.audit_log
  add column if not exists updated_at timestamptz;

-- ---------------------------------------------------------------------
-- stock_movimientos: solo lectura para el cliente
-- ---------------------------------------------------------------------

drop policy if exists "stock_movimientos_tenant" on public.stock_movimientos;
drop policy if exists "stock_movimientos_select" on public.stock_movimientos;
drop policy if exists "stock_movimientos_insert" on public.stock_movimientos;
drop policy if exists "stock_movimientos_update" on public.stock_movimientos;
drop policy if exists "stock_movimientos_delete" on public.stock_movimientos;

create policy "stock_movimientos_select" on public.stock_movimientos
  for select
  using (tenant_id = public.current_tenant_id() or public.is_platform_admin());

-- Sin policies de insert/update/delete: el cliente no escribe.
-- Las RPC security definer (owner) siguen pudiendo insertar.

revoke insert, update, delete on public.stock_movimientos from authenticated, anon;
grant select on public.stock_movimientos to authenticated;

-- ---------------------------------------------------------------------
-- audit_log: SELECT + INSERT (sin update/delete); actor/fecha server-side
-- ---------------------------------------------------------------------

drop policy if exists "audit_log_tenant" on public.audit_log;
drop policy if exists "audit_log_select" on public.audit_log;
drop policy if exists "audit_log_insert" on public.audit_log;
drop policy if exists "audit_log_update" on public.audit_log;
drop policy if exists "audit_log_delete" on public.audit_log;

create policy "audit_log_select" on public.audit_log
  for select
  using (tenant_id = public.current_tenant_id() or public.is_platform_admin());

create policy "audit_log_insert" on public.audit_log
  for insert
  with check (tenant_id = public.current_tenant_id() or public.is_platform_admin());

-- Privilegio de insert solo en columnas que el cliente puede aportar.
revoke insert, update, delete on public.audit_log from authenticated, anon;
grant select on public.audit_log to authenticated;
grant insert (
  actor_nombre,
  accion,
  entidad,
  entidad_id,
  detalle
) on public.audit_log to authenticated;

-- actor_id / created_at los pone el servidor (default + trigger).
alter table public.audit_log
  alter column created_at set default timezone('utc', now());

-- actor_id es texto en el esquema legacy; guardamos auth.uid() como texto.
alter table public.audit_log
  alter column actor_id set default auth.uid()::text;

create or replace function public.trg_audit_log_stamp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nunca confiar en created_at / actor_id del cliente.
  new.created_at := timezone('utc', now());
  new.actor_id := auth.uid()::text;
  new.updated_at := null;
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_audit_log_stamp on public.audit_log;
create trigger trg_audit_log_stamp
  before insert on public.audit_log
  for each row
  execute function public.trg_audit_log_stamp();

-- ---------------------------------------------------------------------
-- Inmutabilidad: rechazar UPDATE/DELETE (salvo que se quite el trigger)
-- ---------------------------------------------------------------------

create or replace function public.trg_reject_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'immutable_audit_trail'
    using errcode = '42501',
          hint = 'stock_movimientos y audit_log son append-only; use un asiento de reversa';
end;
$$;

drop trigger if exists trg_stock_movimientos_no_update on public.stock_movimientos;
create trigger trg_stock_movimientos_no_update
  before update on public.stock_movimientos
  for each row
  execute function public.trg_reject_mutation();

drop trigger if exists trg_stock_movimientos_no_delete on public.stock_movimientos;
create trigger trg_stock_movimientos_no_delete
  before delete on public.stock_movimientos
  for each row
  execute function public.trg_reject_mutation();

drop trigger if exists trg_audit_log_no_update on public.audit_log;
create trigger trg_audit_log_no_update
  before update on public.audit_log
  for each row
  execute function public.trg_reject_mutation();

drop trigger if exists trg_audit_log_no_delete on public.audit_log;
create trigger trg_audit_log_no_delete
  before delete on public.audit_log
  for each row
  execute function public.trg_reject_mutation();

-- Detección: si alguien con privilegios elevados desactiva el trigger de
-- rechazo y hace UPDATE, updated_at queda marcado (se aplica solo si se
-- reemplaza el trigger de rechazo; se deja la columna lista).

revoke all on function public.trg_audit_log_stamp() from public;
revoke all on function public.trg_reject_mutation() from public;

commit;

notify pgrst, 'reload schema';
