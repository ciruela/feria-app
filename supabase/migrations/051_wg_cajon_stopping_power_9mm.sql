-- =====================================================================
-- 051_wg_cajon_stopping_power_9mm.sql
-- ---------------------------------------------------------------------
-- Producto especial (promo) World Guns: "Cajón Stopping Power 9mm".
--
--   1 cajón = 20 cajas = 1000 tiros.
--   Precio cerrado: USD 440 final pagando EFECTIVO / TRANSFERENCIA
--   (y dólar billete). No aplica tarjeta/cuotas.
--
-- Se modela con fixed_prices (mismo mecanismo que Urban Tactical) porque
-- es un precio de promo fijo que NO debe recalcularse con la promo general
-- de munición del tenant (el 10% NO se aplica: 440 / 682.000 ya son finales).
-- Al no cargar tarjeta_ars/cuota*_ars, la app NO muestra tarjeta ni cuotas
-- para este ítem (PricingService._fromFixed).
--
--   efectivo_usd = 440      -> dólar billete = USD 440 final
--   efectivo_ars = 682000   -> efectivo / transferencia = $682.000 final
--
-- Ambos son montos de promo fijos e independientes del tipo de cambio.
-- Si cambia la promo, editar estos valores y re-aplicar (es idempotente).
-- =====================================================================

begin;

do $$
declare
  v_tenant uuid;
  -- Stock inicial de cajones disponibles. Ajustar según lo que haya en la feria.
  v_stock  integer := 30;
begin
  select id into v_tenant
    from public.tenants
   where lower(replace(slug, '_', '-')) in ('world-guns', 'worldguns')
   limit 1;

  if v_tenant is null then
    raise notice 'Tenant world-guns no encontrado; se omite el alta del cajón.';
    return;
  end if;

  insert into public.productos (
    id, tenant_id, type, marca, calibre, codigo, modelo, descripcion,
    precio_usd, rounds_per_box, stock, stock_inicial, activo, fixed_prices
  ) values (
    'wg-cajon-sp-9mm',
    v_tenant,
    'municion',
    'STOPPING POWER',
    '9mm',
    'CAJON-SP-9',
    '',
    'Cajón Stopping Power 9mm — 20 cajas / 1000 tiros. Promo: USD 440 o $682.000 final (efectivo/transferencia).',
    440,          -- precio_usd base / referencia USD del cajón
    1000,         -- 1 "caja" vendible = 1 cajón = 1000 tiros
    v_stock,
    v_stock,
    true,
    jsonb_build_object(
      'efectivo_usd', 440,
      'efectivo_ars', 682000
    )
  )
  on conflict (tenant_id, codigo) where codigo <> '' do update
    set type           = excluded.type,
        marca          = excluded.marca,
        calibre        = excluded.calibre,
        descripcion    = excluded.descripcion,
        precio_usd     = excluded.precio_usd,
        rounds_per_box = excluded.rounds_per_box,
        activo         = true,
        fixed_prices   = excluded.fixed_prices;
end $$;

commit;

notify pgrst, 'reload schema';
