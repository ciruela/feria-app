-- DIAGNÓSTICO READ-ONLY (borrar). Prefijo no numérico => no registra versión.
select jsonb_pretty(jsonb_build_object(
  'world_guns_por_tipo', (
    select jsonb_agg(x order by x->>'type') from (
      select jsonb_build_object(
        'type', p.type,
        'activos', count(*),
        'con_foto', count(*) filter (
          where coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0)
      ) x
      from public.productos p
      where p.tenant_id = 'bfebd543-4aa8-43f7-9480-c3a128f08693' and p.activo
      group by p.type
    ) s
  ),
  'urban_por_tipo', (
    select jsonb_agg(x order by x->>'type') from (
      select jsonb_build_object(
        'type', p.type,
        'activos', count(*),
        'con_foto', count(*) filter (
          where coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0)
      ) x
      from public.productos p
      where p.tenant_id = 'ffbfe690-0624-4308-8504-0454442c2f50' and p.activo
      group by p.type
    ) s
  )
)) as diag;
