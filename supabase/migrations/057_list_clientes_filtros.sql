-- =====================================================================
-- 057_list_clientes_filtros.sql
-- ---------------------------------------------------------------------
-- Amplía los filtros de la tab de clientes:
--   - Búsqueda de texto también matchea CIUDAD y DIRECCIÓN (además de
--     nombre/apellido, DNI, teléfono, mail y CLU).
--   - Orden configurable: 'recent' (última compra), 'name' (apellido A–Z,
--     porque full_name se guarda "APELLIDO NOMBRE") y 'sales' (más compras).
--   - Filtro 'solo con compras' (ventas vigentes > 0).
--   - Filtro por condición fiscal.
--   - Filtro por rango de fecha de última compra.
-- El conteo (saleCount) y la última compra siguen calculándose EN VIVO
-- desde ventas no anuladas (055).
--
-- Se reemplaza la firma de list_clientes: se dropea la vieja (text,int) y se
-- crea la nueva con parámetros nuevos DEFAULTED, de modo que llamadas viejas
-- {p_query, p_limit} sigan resolviendo (sin ventana de rotura en deploy).
-- =====================================================================

begin;

drop function if exists public.list_clientes(text, int);

create or replace function public.list_clientes(
  p_query text default '',
  p_limit int default 1000,
  p_sort text default 'recent',
  p_only_with_sales boolean default false,
  p_fiscal text default '',
  p_from timestamptz default null,
  p_to timestamptz default null
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
  v_sort text := lower(coalesce(nullif(trim(p_sort), ''), 'recent'));
  v_fiscal text := trim(coalesce(p_fiscal, ''));
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
  ),
  base as (
    select
      c.*,
      coalesce(a.cnt, 0) as sale_cnt,
      a.last_at as sale_last
    from public.clientes c
    left join agg a on a.dni_n = c.dni_normalized
    where c.tenant_id = v_tenant
      and (
        v_q = ''
        or c.full_name ilike '%' || v_q || '%'
        or c.phone ilike '%' || v_q || '%'
        or c.email ilike '%' || v_q || '%'
        or c.clu ilike '%' || v_q || '%'
        or c.city ilike '%' || v_q || '%'
        or c.address ilike '%' || v_q || '%'
        or (
          length(v_norm) >= 3
          and c.dni_normalized like '%' || v_norm || '%'
        )
      )
      and (not p_only_with_sales or coalesce(a.cnt, 0) > 0)
      and (v_fiscal = '' or c.fiscal_condition ilike '%' || v_fiscal || '%')
      and (p_from is null or a.last_at >= p_from)
      and (p_to is null or a.last_at <= p_to)
  )
  select jsonb_build_object(
      'id', b.id,
      'fullName', b.full_name,
      'dni', b.dni_normalized,
      'clu', b.clu,
      'cluExpiry', b.clu_expiry,
      'phone', b.phone,
      'email', b.email,
      'fiscalCondition', b.fiscal_condition,
      'address', b.address,
      'city', b.city,
      'notes', b.notes,
      'saleCount', b.sale_cnt,
      'lastSaleAt', b.sale_last
    )
    from base b
    order by
      case when v_sort = 'name'  then b.full_name end asc nulls last,
      case when v_sort = 'sales' then b.sale_cnt end desc,
      case when v_sort not in ('name', 'sales') then b.sale_last end desc nulls last,
      b.full_name asc
    limit v_limit;
end;
$$;

revoke all on function public.list_clientes(text, int, text, boolean, text, timestamptz, timestamptz) from public;
grant execute on function public.list_clientes(text, int, text, boolean, text, timestamptz, timestamptz) to authenticated;

-- ---------------------------------------------------------------------
-- Condiciones fiscales presentes (para poblar el filtro del panel)
-- ---------------------------------------------------------------------

create or replace function public.list_cliente_fiscal_conditions()
returns setof text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  return query
    select distinct trim(c.fiscal_condition)
    from public.clientes c
    where c.tenant_id = v_tenant
      and coalesce(trim(c.fiscal_condition), '') <> ''
    order by 1;
end;
$$;

revoke all on function public.list_cliente_fiscal_conditions() from public;
grant execute on function public.list_cliente_fiscal_conditions() to authenticated;

commit;

notify pgrst, 'reload schema';
