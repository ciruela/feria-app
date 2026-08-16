-- DIAGNÓSTICO READ-ONLY (borrar). Prefijo no numérico => no registra versión.
select jsonb_pretty(jsonb_build_object(
  'productos_foto_cols', (
    select jsonb_agg(column_name order by column_name)
    from information_schema.columns
    where table_schema = 'public' and table_name = 'productos'
      and (column_name ilike '%foto%' or column_name ilike '%imagen%'
           or column_name ilike '%image%')
  ),
  'productos_all_cols', (
    select jsonb_agg(column_name order by column_name)
    from information_schema.columns
    where table_schema = 'public' and table_name = 'productos'
  ),
  'pricing_world_guns', (
    select pricing_settings from public.app_config
    where tenant_id = 'bfebd543-4aa8-43f7-9480-c3a128f08693' and id = 'global'
  ),
  'pricing_urban', (
    select pricing_settings from public.app_config
    where tenant_id = 'ffbfe690-0624-4308-8504-0454442c2f50' and id = 'global'
  )
)) as diag;
