-- DIAGNÓSTICO READ-ONLY (borrar). Prefijo no numérico => no registra versión.
select jsonb_pretty(jsonb_build_object(
  'bucket_fotos', (
    select jsonb_build_object('id', id, 'public', public)
    from storage.buckets where id = 'feria-fotos'
  ),
  'fotos_activo_vs_inactivo', (
    select jsonb_agg(x order by x->>'tenant') from (
      select jsonb_build_object(
        'tenant', tn.slug,
        'activos_con_fotos', count(*) filter (
          where p.activo and coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0),
        'inactivos_con_fotos', count(*) filter (
          where not p.activo and coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0),
        'total_activos', count(*) filter (where p.activo),
        'total_inactivos', count(*) filter (where not p.activo)
      ) x
      from public.productos p
      join public.tenants tn on tn.id = p.tenant_id
      group by tn.slug
    ) s
  ),
  'objetos_storage_por_tenant', (
    select jsonb_agg(x order by x->>'prefijo') from (
      select jsonb_build_object(
        'prefijo', (storage.foldername(name))[1],
        'n', count(*)
      ) x
      from storage.objects
      where bucket_id = 'feria-fotos'
      group by (storage.foldername(name))[1]
    ) s
  )
)) as diag;
