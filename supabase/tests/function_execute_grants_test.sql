-- AR-16: funciones sensibles NO deben ser ejecutables por anon.
-- Correr en SQL Editor / CI de schema checks.
-- Esperado: 0 filas.

select p.proname as exposed_to_anon
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
  and p.proname in (
    'register_sale',
    'void_sale',
    'set_venta_facturada',
    'set_product_stock',
    'hash_portal_code',
    'verify_portal_code',
    'touch_seller_portal_rate_limit',
    'validate_seller_portal',
    'list_ventas_for_range',
    'search_ventas_by_dni',
    'apply_product_stock_delta',
    'normalize_dni',
    '_sale_clamp_pct',
    '_sale_unit_ars'
  )
  and exists (
    select 1
    from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where a.privilege_type = 'EXECUTE'
      and a.grantee = (select oid from pg_roles where rolname = 'anon')
  )
order by 1;
