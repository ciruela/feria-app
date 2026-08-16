-- DIAGNÓSTICO READ-ONLY (borrar después). No registra versión (prefijo no numérico).
select jsonb_pretty(jsonb_build_object(
  'clientes_por_tenant', (
    select jsonb_agg(x order by x->>'n' desc) from (
      select jsonb_build_object('tenant_id', t.tenant_id, 'slug', tn.slug, 'n', t.n) as x
      from (select tenant_id, count(*) as n from public.clientes group by tenant_id) t
      left join public.tenants tn on tn.id = t.tenant_id
    ) s
  ),
  'ventas_por_tenant', (
    select jsonb_agg(x) from (
      select jsonb_build_object(
        'tenant_id', tenant_id,
        'total', count(*),
        'anuladas', count(*) filter (where coalesce(anulada,false)),
        'con_dni', count(*) filter (where length(public.normalize_dni(cliente_dni)) >= 6)
      ) as x
      from public.ventas group by tenant_id
    ) s
  ),
  'clientes_dup_dni', (
    select count(*) from (
      select tenant_id, dni_normalized from public.clientes
      group by tenant_id, dni_normalized having count(*) > 1
    ) d
  ),
  'sample_top_stored', (
    select jsonb_agg(x) from (
      select jsonb_build_object(
        'tenant_id', c.tenant_id,
        'name', c.full_name,
        'dni', c.dni_normalized,
        'stored', c.sale_count,
        'live', (
          select count(*) from public.ventas v
          where v.tenant_id = c.tenant_id
            and not coalesce(v.anulada,false)
            and public.normalize_dni(v.cliente_dni) = c.dni_normalized
        )
      ) as x
      from public.clientes c
      order by c.sale_count desc
      limit 8
    ) s
  )
)) as diag;
