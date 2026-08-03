-- =====================================================================
-- 018_stock_delta_tenant_guard.sql
-- ---------------------------------------------------------------------
-- FIX (fuga cross-tenant): en 017, la rama `p_delta = 0` de
-- apply_product_stock_delta leía el stock SIN filtrar por tenant. Como la
-- función es `security definer` (bypassa RLS), cualquier usuario autenticado
-- que conociera el id de un producto de OTRA armería podía leer su stock
-- pasando p_delta=0.
--
-- Solución: aplicar el mismo chequeo de tenant (current_tenant_id o platform
-- admin) también en la rama delta=0. El resto de la función queda igual que 017.
--
-- Seguro de aplicar: el uso legítimo siempre opera sobre el tenant activo, así
-- que no cambia el comportamiento de ventas/anulaciones/cargas.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor (después de 017).
-- =====================================================================

begin;

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
begin
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
    p_venta_id,
    p_vendedor_id,
    coalesce(p_nota, ''),
    v_tenant
  );

  return v_next;
end;
$$;

revoke all on function public.apply_product_stock_delta(text, integer, text, text, text, text) from public;
grant execute on function public.apply_product_stock_delta(text, integer, text, text, text, text) to authenticated;

commit;
