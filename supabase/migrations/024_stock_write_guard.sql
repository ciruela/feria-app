-- =====================================================================
-- 024_stock_write_guard.sql
-- ---------------------------------------------------------------------
-- AR-6: el stock no puede modificarse por PATCH/upsert sin movimiento.
--
-- 1) apply_product_stock_delta marca sesión para no duplicar movimientos.
-- 2) set_product_stock: seteo absoluto (ajuste/import/alta), con rastro.
-- 3) Trigger AFTER INSERT/UPDATE OF stock: red de seguridad.
-- 4) revoke update(stock) on productos; revoke writes on stock_movimientos.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- apply_product_stock_delta: flag de sesión + nota (ya existía)
-- ---------------------------------------------------------------------

create or replace function public.apply_product_stock_delta(
  p_product_id text,
  p_delta integer,
  p_motivo text,
  p_venta_id text default null,
  p_vendedor_id text default null,
  p_nota text default ''
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current integer;
  v_next integer;
  v_tenant uuid;
  v_venta_id uuid;
begin
  v_venta_id := nullif(trim(p_venta_id), '')::uuid;

  if p_delta = 0 then
    select stock into v_current
      from public.productos
     where id = p_product_id
       and (tenant_id = public.current_tenant_id() or public.is_platform_admin());
    if not found then
      raise exception 'product_not_found';
    end if;
    if v_current is null then
      raise exception 'stock_not_tracked';
    end if;
    return v_current;
  end if;

  select stock, tenant_id
    into v_current, v_tenant
    from public.productos
   where id = p_product_id
     and (tenant_id = public.current_tenant_id() or public.is_platform_admin())
   for update;

  if not found then
    raise exception 'product_not_found';
  end if;

  if v_current is null then
    raise exception 'stock_not_tracked';
  end if;

  v_next := v_current + p_delta;
  if v_next < 0 then
    raise exception 'insufficient_stock';
  end if;

  -- Evita que el trigger de auditoría duplique el movimiento.
  perform set_config('app.stock_via_rpc', '1', true);

  update public.productos
     set stock = v_next,
         updated_at = now()
   where id = p_product_id;

  insert into public.stock_movimientos (
    producto_id,
    delta,
    motivo,
    stock_antes,
    stock_despues,
    venta_id,
    vendedor_id,
    nota,
    tenant_id
  ) values (
    p_product_id,
    p_delta,
    p_motivo,
    v_current,
    v_next,
    v_venta_id,
    nullif(trim(p_vendedor_id), ''),
    coalesce(p_nota, ''),
    v_tenant
  );

  return v_next;
end;
$$;

-- ---------------------------------------------------------------------
-- set_product_stock: valor absoluto (ajuste manual / import / alta)
-- ---------------------------------------------------------------------

create or replace function public.set_product_stock(
  p_product_id text,
  p_stock integer,
  p_motivo text default 'ajuste',
  p_nota text default ''
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current integer;
  v_next integer;
  v_delta integer;
  v_tenant uuid;
  v_motivo text;
begin
  if p_stock is null or p_stock < 0 then
    raise exception 'invalid_stock';
  end if;

  v_motivo := coalesce(nullif(trim(p_motivo), ''), 'ajuste');
  if v_motivo not in ('carga', 'ajuste', 'venta', 'anulacion') then
    v_motivo := 'ajuste';
  end if;

  select stock, tenant_id
    into v_current, v_tenant
    from public.productos
   where id = p_product_id
     and (tenant_id = public.current_tenant_id() or public.is_platform_admin())
   for update;

  if not found then
    raise exception 'product_not_found';
  end if;

  v_next := p_stock;
  if v_current is not distinct from v_next then
    return v_next;
  end if;

  v_delta := v_next - coalesce(v_current, 0);

  perform set_config('app.stock_via_rpc', '1', true);

  update public.productos
     set stock = v_next,
         updated_at = now()
   where id = p_product_id;

  insert into public.stock_movimientos (
    producto_id,
    delta,
    motivo,
    stock_antes,
    stock_despues,
    venta_id,
    vendedor_id,
    nota,
    tenant_id
  ) values (
    p_product_id,
    v_delta,
    v_motivo,
    coalesce(v_current, 0),
    v_next,
    null,
    null,
    coalesce(p_nota, ''),
    v_tenant
  );

  return v_next;
end;
$$;

-- ---------------------------------------------------------------------
-- Trigger: red de seguridad si alguien actualiza stock fuera de las RPC
-- ---------------------------------------------------------------------

create or replace function public.trg_productos_stock_movimiento()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta integer;
begin
  if current_setting('app.stock_via_rpc', true) = '1' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.stock is not distinct from old.stock then
      return new;
    end if;
    v_delta := coalesce(new.stock, 0) - coalesce(old.stock, 0);
    if v_delta = 0 and new.stock is null then
      return new;
    end if;

    insert into public.stock_movimientos (
      producto_id,
      delta,
      motivo,
      stock_antes,
      stock_despues,
      nota,
      tenant_id
    ) values (
      new.id,
      v_delta,
      'ajuste',
      old.stock,
      new.stock,
      'auditoria automatica (update externo)',
      new.tenant_id
    );
  elsif tg_op = 'INSERT' then
    if new.stock is null then
      return new;
    end if;

    insert into public.stock_movimientos (
      producto_id,
      delta,
      motivo,
      stock_antes,
      stock_despues,
      nota,
      tenant_id
    ) values (
      new.id,
      new.stock,
      'carga',
      0,
      new.stock,
      'auditoria automatica (alta con stock)',
      new.tenant_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_productos_stock_movimiento on public.productos;
create trigger trg_productos_stock_movimiento
  after insert or update of stock on public.productos
  for each row
  execute function public.trg_productos_stock_movimiento();

-- ---------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------

revoke all on function public.apply_product_stock_delta(text, integer, text, text, text, text) from public;
grant execute on function public.apply_product_stock_delta(text, integer, text, text, text, text) to authenticated;

revoke all on function public.set_product_stock(text, integer, text, text) from public;
grant execute on function public.set_product_stock(text, integer, text, text) to authenticated;

revoke all on function public.trg_productos_stock_movimiento() from public;

-- Único camino de escritura de stock para el cliente: las RPC (security definer).
revoke update (stock) on public.productos from authenticated, anon;

-- El rastro no lo declara ni borra el cliente (CONC-005 / CONC-008).
revoke insert, update, delete on public.stock_movimientos from authenticated, anon;

commit;

notify pgrst, 'reload schema';
