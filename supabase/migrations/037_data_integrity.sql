-- =====================================================================
-- 037_data_integrity.sql
-- ---------------------------------------------------------------------
-- AR-23: el modelo no defiende sus invariantes.
--   1. FK stock_movimientos.producto_id -> productos.id (on delete restrict)
--      NOT VALID: respeta filas históricas huérfanas (inmutables, AR-7)
--      pero exige integridad en TODO movimiento nuevo.
--   2. CHECK de dominio: stock >= 0, precio_usd >= 0 (no hay violaciones).
-- =====================================================================

begin;

-- 1. Integridad referencial de movimientos hacia productos.
--    NOT VALID: no revalida los 11 movimientos huérfanos históricos
--    (de productos QA ya borrados; inmutables por AR-7), pero sí obliga
--    a que todo movimiento nuevo apunte a un producto existente y bloquea
--    el borrado de un producto con historial (on delete restrict).
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'stock_movimientos_producto_id_fkey'
      and conrelid = 'public.stock_movimientos'::regclass
  ) then
    alter table public.stock_movimientos
      add constraint stock_movimientos_producto_id_fkey
      foreign key (producto_id) references public.productos (id)
      on delete restrict
      not valid;
  end if;
end $$;

-- 2. CHECK de dominio (mismo patrón que productos_type_check).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'productos_stock_no_negativo'
  ) then
    alter table public.productos
      add constraint productos_stock_no_negativo check (stock is null or stock >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'productos_precio_no_negativo'
  ) then
    alter table public.productos
      add constraint productos_precio_no_negativo check (precio_usd >= 0);
  end if;
  if not exists (
    select 1 from pg_constraint where conname = 'productos_stock_inicial_no_negativo'
  ) then
    alter table public.productos
      add constraint productos_stock_inicial_no_negativo
      check (stock_inicial is null or stock_inicial >= 0);
  end if;
end $$;

commit;
