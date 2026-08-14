-- Smoke test post 053/054 (esperado: filas con conteos > 0 si hay ventas con DNI).
select 'clientes_total' as check_name, count(*)::text as value from public.clientes
union all
select 'ventas_con_dni', count(*)::text
from public.ventas
where length(public.normalize_dni(cliente_dni)) >= 6
  and not coalesce(anulada, false)
union all
select 'fn_lookup', case when exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'lookup_cliente_by_dni'
) then 'ok' else 'missing' end
union all
select 'fn_list', case when exists (
  select 1 from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'list_clientes'
) then 'ok' else 'missing' end
union all
select 'trigger', case when exists (
  select 1 from pg_trigger where tgname = 'ventas_upsert_cliente'
) then 'ok' else 'missing' end;
