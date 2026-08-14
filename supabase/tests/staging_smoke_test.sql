select 'tenants' as tbl, count(*)::text as n from public.tenants
union all select 'clientes', count(*)::text from public.clientes
union all select 'productos', count(*)::text from public.productos
union all select 'lookup_cliente', case when exists (
  select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'lookup_cliente_by_dni'
) then 'ok' else 'missing' end;
