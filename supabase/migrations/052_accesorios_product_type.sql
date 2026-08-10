-- =====================================================================
-- 052_accesorios_product_type.sql
-- ---------------------------------------------------------------------
-- Amplía el dominio de productos.type para incluir la categoría
-- 'accesorios' (fundas, linternas, etc.), además de la munición y armas.
--
-- Es defensiva e idempotente: si existe un CHECK sobre `type` (con
-- cualquier nombre) que aún no contempla 'accesorios', lo reemplaza por
-- el canónico. Si no existe ninguno, simplemente crea el canónico.
--
-- Orden de deploy seguro (para NO romper apps viejas ni Urban en prod):
--   1) aplicar esta migración,
--   2) desplegar la app con soporte 'accesorios',
--   3) recién entonces importar/crear productos 'accesorios'.
-- (fromKey en la app ya cae en 'municion' ante un tipo desconocido, así
--  que un cliente desactualizado no crashea aunque vea un accesorio.)
-- =====================================================================

begin;

do $$
declare
  c record;
begin
  -- Elimina cualquier CHECK sobre productos que valide `type` (independiente
  -- del nombre) para no dejar un constraint viejo que rechace 'accesorios'.
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.productos'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%municion%'
  loop
    execute format('alter table public.productos drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.productos
  add constraint productos_type_check
  check (type in ('municion', 'arma_corta', 'arma_larga', 'accesorios'));

commit;

notify pgrst, 'reload schema';
