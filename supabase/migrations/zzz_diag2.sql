-- DIAGNÓSTICO READ-ONLY (borrar). Prefijo no numérico => no registra versión.
select jsonb_pretty(jsonb_build_object(
  'por_tenant', (
    select jsonb_agg(x order by x->>'tenant') from (
      select jsonb_build_object(
        'tenant', tn.slug,
        'activos', count(*) filter (where p.activo),
        'con_fotos', count(*) filter (where coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0),
        'con_foto_url', count(*) filter (where coalesce(p.foto_url, '') <> ''),
        'con_foto', count(*) filter (where coalesce(p.foto, '') <> '')
      ) x
      from public.productos p
      join public.tenants tn on tn.id = p.tenant_id
      group by tn.slug
    ) s
  ),
  'sample_world_guns', (
    select jsonb_agg(x) from (
      select jsonb_build_object(
        'codigo', p.codigo, 'type', p.type,
        'foto', p.foto, 'foto_url', p.foto_url, 'fotos', to_jsonb(p.fotos)
      ) x
      from public.productos p
      where p.tenant_id = 'bfebd543-4aa8-43f7-9480-c3a128f08693' and p.activo
      order by p.updated_at desc
      limit 6
    ) s
  ),
  'sample_urban', (
    select jsonb_agg(x) from (
      select jsonb_build_object(
        'codigo', p.codigo, 'type', p.type,
        'foto', p.foto, 'foto_url', p.foto_url, 'fotos', to_jsonb(p.fotos)
      ) x
      from public.productos p
      where p.tenant_id = 'ffbfe690-0624-4308-8504-0454442c2f50' and p.activo
      order by p.updated_at desc
      limit 6
    ) s
  )
)) as diag;
