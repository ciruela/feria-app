-- =====================================================================
-- 052_accesorios_product_type.sql
-- ---------------------------------------------------------------------
-- Ampliar dominio de productos.type para la categoría accesorios.
-- =====================================================================

begin;

do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'productos_type_check'
      and conrelid = 'public.productos'::regclass
  ) then
    alter table public.productos drop constraint productos_type_check;
  end if;
end $$;

alter table public.productos
  add constraint productos_type_check
  check (type in ('municion', 'arma_corta', 'arma_larga', 'accesorios'));

commit;
