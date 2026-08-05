-- =====================================================================
-- 026_void_sale_idempotent.sql
-- ---------------------------------------------------------------------
-- AR-8: la doble anulación no debe restituir stock dos veces.
--
-- 1) void_sale atómica: UPDATE ... WHERE anulada = false; 0 filas → no-op.
-- 2) Restituye stock desde stock_movimientos (motivo=venta), no desde
--    items mutables; fallback a items solo si no hay movimientos.
-- 3) Trigger: items/totales inmutables; no se puede reactivar (anulada→false).
-- 4) Reafirma revoke update/delete on ventas (defensa en profundidad).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- void_sale endurecida
-- ---------------------------------------------------------------------

create or replace function public.void_sale(
  p_venta_id uuid,
  p_motivo text,
  p_actor_nombre text default ''
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_sale record;
  v_line jsonb;
  v_qty_by_product jsonb := '{}'::jsonb;
  v_pid text;
  v_qty integer;
  v_updated uuid;
begin
  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required';
  end if;

  if nullif(trim(coalesce(p_motivo, '')), '') is null then
    raise exception 'motivo_required';
  end if;

  select id, anulada, items, vendedor_id
    into v_sale
    from public.ventas
   where id = p_venta_id
     and tenant_id = v_tenant
   for update;

  if not found then
    return false;
  end if;

  if coalesce(v_sale.anulada, false) then
    -- Idempotente: segunda anulación no toca stock.
    return false;
  end if;

  -- Preferir el rastro real de la venta (anti-TOCTOU sobre items).
  select coalesce(
    jsonb_object_agg(producto_id, qty),
    '{}'::jsonb
  )
    into v_qty_by_product
    from (
      select
        producto_id,
        (-sum(delta))::integer as qty
      from public.stock_movimientos
      where venta_id = p_venta_id
        and tenant_id = v_tenant
        and motivo = 'venta'
        and delta < 0
      group by producto_id
    ) movimientos;

  if v_qty_by_product = '{}'::jsonb then
    for v_line in
      select value
        from jsonb_array_elements(coalesce(v_sale.items->'lines', '[]'::jsonb))
    loop
      v_pid := nullif(trim(coalesce(v_line->>'productId', '')), '');
      v_qty := floor(coalesce((v_line->>'quantity')::numeric, 0));
      if v_pid is null or v_qty <= 0 then
        continue;
      end if;
      v_qty_by_product := jsonb_set(
        v_qty_by_product,
        array[v_pid],
        to_jsonb(coalesce((v_qty_by_product->>v_pid)::integer, 0) + v_qty)
      );
    end loop;
  end if;

  -- Casilla atómica: si otro worker ganó la carrera, 0 filas.
  update public.ventas
     set anulada = true,
         anulada_motivo = left(trim(p_motivo), 500),
         anulada_por = left(coalesce(p_actor_nombre, ''), 200),
         anulada_at = timezone('utc', now())
   where id = p_venta_id
     and tenant_id = v_tenant
     and coalesce(anulada, false) = false
  returning id into v_updated;

  if v_updated is null then
    return false;
  end if;

  for v_pid in select key from jsonb_each(v_qty_by_product)
  loop
    v_qty := (v_qty_by_product->>v_pid)::integer;
    if v_qty <= 0 then
      continue;
    end if;
    perform public.apply_product_stock_delta(
      v_pid,
      v_qty,
      'anulacion',
      p_venta_id::text,
      v_sale.vendedor_id,
      left(trim(p_motivo), 200)
    );
  end loop;

  return true;
end;
$$;

revoke all on function public.void_sale(uuid, text, text) from public;
grant execute on function public.void_sale(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- Inmutabilidad de campos contables / anti-reactivación
-- ---------------------------------------------------------------------

create or replace function public.trg_ventas_immutable_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.items is distinct from new.items
     or old.total_usd is distinct from new.total_usd
     or old.total_ars is distinct from new.total_ars
     or old.tipo_cambio is distinct from new.tipo_cambio
     or old.cliente_dni is distinct from new.cliente_dni
     or old.cliente_nombre is distinct from new.cliente_nombre
     or old.metodo_pago is distinct from new.metodo_pago
     or old.vendedor_id is distinct from new.vendedor_id
     or old.idempotency_key is distinct from new.idempotency_key
  then
    raise exception 'venta_fields_immutable'
      using errcode = '42501',
            hint = 'items/totales de una venta no se editan; anule y registre otra';
  end if;

  if coalesce(old.anulada, false) and not coalesce(new.anulada, false) then
    raise exception 'cannot_reactivate_sale'
      using errcode = '42501',
            hint = 'una venta anulada no se reactiva';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ventas_immutable_fields on public.ventas;
create trigger trg_ventas_immutable_fields
  before update on public.ventas
  for each row
  execute function public.trg_ventas_immutable_fields();

revoke all on function public.trg_ventas_immutable_fields() from public;

-- Defensa: el cliente no hace PATCH sobre ventas (solo RPCs security definer).
revoke insert, update, delete on public.ventas from authenticated, anon;
grant select on public.ventas to authenticated;

commit;

notify pgrst, 'reload schema';
