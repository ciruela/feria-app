-- =====================================================================
-- 056_list_clientes_limit.sql
-- ---------------------------------------------------------------------
-- FIX (la tab de clientes mostraba solo 100 y parecía "igual" en todos
-- los tenants): `list_clientes` topeaba el resultado en 200 y la app pedía
-- 100, así que tenants con >100 clientes mostraban siempre 100 (no es fuga
-- de tenant; el filtro por tenant_id ya es correcto).
--
-- Se sube el tope a 5000 (las tablas son chicas: cientos de filas) para que
-- se listen todos los clientes del tenant. La búsqueda sigue disponible para
-- filtrar. El conteo de comprobantes (saleCount) ya es en vivo desde 055.
-- =====================================================================

begin;

create or replace function public.list_clientes(
  p_query text default '',
  p_limit int default 1000
)
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_q text := trim(coalesce(p_query, ''));
  v_norm text := public.normalize_dni(v_q);
  v_limit int := least(greatest(coalesce(p_limit, 1000), 1), 5000);
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  return query
  with agg as (
    select
      public.normalize_dni(v.cliente_dni) as dni_n,
      count(*)::int as cnt,
      max(v.created_at) as last_at
    from public.ventas v
    where v.tenant_id = v_tenant
      and not coalesce(v.anulada, false)
    group by public.normalize_dni(v.cliente_dni)
  )
  select jsonb_build_object(
      'id', c.id,
      'fullName', c.full_name,
      'dni', c.dni_normalized,
      'clu', c.clu,
      'cluExpiry', c.clu_expiry,
      'phone', c.phone,
      'email', c.email,
      'fiscalCondition', c.fiscal_condition,
      'address', c.address,
      'city', c.city,
      'notes', c.notes,
      'saleCount', coalesce(a.cnt, 0),
      'lastSaleAt', a.last_at
    )
    from public.clientes c
    left join agg a on a.dni_n = c.dni_normalized
    where c.tenant_id = v_tenant
      and (
        v_q = ''
        or c.full_name ilike '%' || v_q || '%'
        or c.phone ilike '%' || v_q || '%'
        or c.email ilike '%' || v_q || '%'
        or c.clu ilike '%' || v_q || '%'
        or (
          length(v_norm) >= 3
          and c.dni_normalized like '%' || v_norm || '%'
        )
      )
    order by a.last_at desc nulls last, c.full_name asc
    limit v_limit;
end;
$$;

revoke all on function public.list_clientes(text, int) from public;
grant execute on function public.list_clientes(text, int) to authenticated;

commit;

notify pgrst, 'reload schema';
