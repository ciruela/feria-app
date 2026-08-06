-- =====================================================================
-- 041_urban_fixed_prices.sql
-- ---------------------------------------------------------------------
-- Precios fijos por producto, cargados tal cual desde el Excel de un
-- tenant (Urban Tactical). A diferencia del resto del catálogo, estos
-- productos NO recalculan precios: la app muestra estos montos fielmente.
--
-- Formato del JSON (todas las claves opcionales, montos en ARS salvo
-- efectivo_usd que es referencia en dólares de armas cotizadas en USD):
--   {
--     "efectivo_ars": 5495000,   -- efectivo / transferencia
--     "efectivo_usd": 3500,      -- referencia USD (armas Gral/Taurus)
--     "tarjeta_ars": 5659850,    -- PVP tarjeta 1 pago
--     "cuota3_ars": 2058864.77,  -- valor de CADA cuota (3 cuotas)
--     "cuota6_ars": 1100463.50,  -- valor de CADA cuota (6 cuotas)
--     "cuota12_ars": 644232.43   -- valor de CADA cuota (12 cuotas)
--   }
-- Null = producto normal (la app calcula precios como siempre).
-- =====================================================================

begin;

alter table public.productos
  add column if not exists fixed_prices jsonb;

comment on column public.productos.fixed_prices is
  'Precios fijos del Excel (Urban): efectivo_ars, efectivo_usd, tarjeta_ars, '
  'cuota3_ars, cuota6_ars, cuota12_ars. Null = precios calculados por la app.';

-- AR-26: grants por columna. Sumar fixed_prices a insert/update de authenticated
-- (036 reemplazó los grants de tabla por grants por columna).
grant insert (fixed_prices) on public.productos to authenticated;
grant update (fixed_prices) on public.productos to authenticated;

commit;
