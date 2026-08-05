-- =====================================================================
-- 028_sale_stock_integrity.sql
-- ---------------------------------------------------------------------
-- AR-10: integridad venta ↔ movimiento (complementa register_sale de 023).
--
-- 1) FK stock_movimientos.venta_id → ventas(id)
-- 2) Constraint trigger diferido: al commit, toda venta no anulada debe
--    tener movimientos cuya suma de cantidades coincida con items.
-- 3) Reafirma unique(tenant_id, idempotency_key) y revoke insert ventas.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Limpiar huérfanos antes del FK (movimientos de QA / legacy)
-- ---------------------------------------------------------------------

update public.stock_movimientos sm
   set venta_id = null
 where sm.venta_id is not null
   and not exists (
     select 1 from public.ventas v where v.id = sm.venta_id
   );

do $$
begin
  if not exists (
    select 1
      from pg_constraint
     where conname = 'stock_movimientos_venta_id_fkey'
  ) then
    alter table public.stock_movimientos
      add constraint stock_movimientos_venta_id_fkey
      foreign key (venta_id)
      references public.ventas (id)
      on delete restrict;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Al commit: venta activa ⇒ movimientos de stock coherentes
-- ---------------------------------------------------------------------

create or replace function public.trg_venta_requiere_movimientos()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expected integer;
  v_got integer;
begin
  if coalesce(new.anulada, false) then
    return null;
  end if;

  select coalesce(sum(greatest(floor(coalesce((line->>'quantity')::numeric, 0)), 0)), 0)
    into v_expected
    from jsonb_array_elements(coalesce(new.items->'lines', '[]'::jsonb)) as line
   where nullif(trim(coalesce(line->>'productId', '')), '') is not null;

  if v_expected <= 0 then
    raise exception 'sale_missing_stock_movements'
      using hint = 'la venta no tiene cantidades válidas en items';
  end if;

  select coalesce(sum(-delta), 0)
    into v_got
    from public.stock_movimientos
   where venta_id = new.id
     and motivo = 'venta'
     and delta < 0;

  if v_got <> v_expected then
    raise exception 'sale_missing_stock_movements'
      using hint = format(
        'venta %s: esperado %s unidades en movimientos, hay %s',
        new.id, v_expected, v_got
      );
  end if;

  return null;
end;
$$;

drop trigger if exists trg_venta_requiere_movimientos on public.ventas;
create constraint trigger trg_venta_requiere_movimientos
  after insert on public.ventas
  deferrable initially deferred
  for each row
  execute function public.trg_venta_requiere_movimientos();

revoke all on function public.trg_venta_requiere_movimientos() from public;

-- Idempotencia (por si 023 no se aplicó completo en algún entorno)
alter table public.ventas
  add column if not exists idempotency_key text;

create unique index if not exists ventas_tenant_idempotency_uidx
  on public.ventas (tenant_id, idempotency_key)
  where idempotency_key is not null;

revoke insert, update, delete on public.ventas from authenticated, anon;
grant select on public.ventas to authenticated;

commit;

notify pgrst, 'reload schema';
