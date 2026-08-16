-- =====================================================================
-- 055_clientes_sale_count_fiel.sql
-- ---------------------------------------------------------------------
-- FIX (conteo de comprobantes por cliente no fiel):
--   El contador `clientes.sale_count` se mantenía con un incremento (+1)
--   en cada upsert (trigger/backfill). Eso NO es fiel:
--     1. Si el backfill corre más de una vez (re-aplicar 053, o aplicación
--        previa por SQL Editor), cada cliente se duplica (1 -> 2 -> ...).
--        => Síntoma reportado: "todos los clientes figuran con 2".
--     2. Al anular una venta (UPDATE de `anulada`) el contador no baja,
--        porque el trigger solo corre en INSERT.
--
-- Solución (fuente de verdad = tabla `ventas`, ventas NO anuladas):
--   1. `list_clientes` / `get_cliente_by_id` calculan `saleCount` y
--      `lastSaleAt` EN VIVO desde `ventas` (self-healing; refleja anulaciones).
--   2. Reparación puntual del valor guardado (`sale_count`, `last_sale_at`).
--   3. `upsert_cliente_from_sale` pasa a RECOMPUTAR el conteo (idempotente),
--      en vez de sumar +1, para que no vuelva a inflarse nunca más.
--
-- El match cliente<->venta es por (tenant_id, normalize_dni(cliente_dni)).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Reparación puntual del contador y última venta desde ventas reales
-- ---------------------------------------------------------------------

update public.clientes c
set sale_count = coalesce(agg.cnt, 0),
    last_sale_at = agg.last_at,
    updated_at = now()
from (
  select
    v.tenant_id,
    public.normalize_dni(v.cliente_dni) as dni_n,
    count(*)::int as cnt,
    max(v.created_at) as last_at
  from public.ventas v
  where not coalesce(v.anulada, false)
    and length(public.normalize_dni(v.cliente_dni)) >= 6
  group by v.tenant_id, public.normalize_dni(v.cliente_dni)
) agg
where agg.tenant_id = c.tenant_id
  and agg.dni_n = c.dni_normalized;

-- Clientes sin ventas vigentes (p. ej. todas anuladas) -> 0.
update public.clientes c
set sale_count = 0,
    last_sale_at = null,
    updated_at = now()
where not exists (
  select 1
  from public.ventas v
  where v.tenant_id = c.tenant_id
    and not coalesce(v.anulada, false)
    and public.normalize_dni(v.cliente_dni) = c.dni_normalized
);

-- ---------------------------------------------------------------------
-- 2. Upsert idempotente: recomputar el conteo, no sumar +1
-- ---------------------------------------------------------------------

create or replace function public.upsert_cliente_from_sale(
  p_tenant_id uuid,
  p_dni text,
  p_customer jsonb,
  p_cliente_nombre text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text := public.normalize_dni(p_dni);
  v_c jsonb := coalesce(p_customer, '{}'::jsonb);
  v_name text;
  v_count int;
  v_last timestamptz;
begin
  if p_tenant_id is null or length(v_norm) < 6 then
    return;
  end if;

  v_name := left(
    coalesce(
      nullif(trim(v_c->>'fullName'), ''),
      nullif(trim(p_cliente_nombre), ''),
      ''
    ),
    200
  );

  -- Fuente de verdad: ventas no anuladas del tenant para ese DNI.
  select count(*)::int, max(v.created_at)
    into v_count, v_last
  from public.ventas v
  where v.tenant_id = p_tenant_id
    and not coalesce(v.anulada, false)
    and public.normalize_dni(v.cliente_dni) = v_norm;

  -- Al dispararse por trigger AFTER INSERT, la venta nueva ya está contada.
  -- El backfill llama a esta función por cada venta: siempre fija el total real.
  if v_count is null then
    v_count := 0;
  end if;

  insert into public.clientes (
    tenant_id,
    dni_normalized,
    full_name,
    clu,
    clu_expiry,
    phone,
    email,
    fiscal_condition,
    address,
    city,
    notes,
    last_sale_at,
    sale_count
  ) values (
    p_tenant_id,
    v_norm,
    v_name,
    left(coalesce(v_c->>'clu', ''), 80),
    left(coalesce(v_c->>'cluExpiry', ''), 20),
    left(coalesce(v_c->>'phone', ''), 40),
    left(coalesce(v_c->>'email', ''), 120),
    left(coalesce(v_c->>'fiscalCondition', ''), 80),
    left(coalesce(v_c->>'address', ''), 200),
    left(coalesce(v_c->>'city', ''), 80),
    left(coalesce(v_c->>'notes', ''), 500),
    v_last,
    greatest(v_count, 1)
  )
  on conflict (tenant_id, dni_normalized) do update set
    full_name = coalesce(
      nullif(trim(excluded.full_name), ''),
      clientes.full_name
    ),
    clu = coalesce(nullif(trim(excluded.clu), ''), clientes.clu),
    clu_expiry = coalesce(
      nullif(trim(excluded.clu_expiry), ''),
      clientes.clu_expiry
    ),
    phone = coalesce(nullif(trim(excluded.phone), ''), clientes.phone),
    email = coalesce(nullif(trim(excluded.email), ''), clientes.email),
    fiscal_condition = coalesce(
      nullif(trim(excluded.fiscal_condition), ''),
      clientes.fiscal_condition
    ),
    address = coalesce(nullif(trim(excluded.address), ''), clientes.address),
    city = coalesce(nullif(trim(excluded.city), ''), clientes.city),
    notes = coalesce(nullif(trim(excluded.notes), ''), clientes.notes),
    -- Recompute idempotente (no +1): fija el total real.
    sale_count = excluded.sale_count,
    last_sale_at = coalesce(excluded.last_sale_at, clientes.last_sale_at),
    updated_at = now();
end;
$$;

revoke all on function public.upsert_cliente_from_sale(uuid, text, jsonb, text) from public;

-- ---------------------------------------------------------------------
-- 3. Listado con conteo EN VIVO (fuente de verdad = ventas no anuladas)
-- ---------------------------------------------------------------------

create or replace function public.list_clientes(
  p_query text default '',
  p_limit int default 100
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
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
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

-- ---------------------------------------------------------------------
-- 4. Detalle por id con conteo EN VIVO
-- ---------------------------------------------------------------------

create or replace function public.get_cliente_by_id(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_row public.clientes%rowtype;
  v_count int;
  v_last timestamptz;
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  if p_id is null then
    return null;
  end if;

  select * into v_row
    from public.clientes c
   where c.tenant_id = v_tenant
     and c.id = p_id;

  if v_row.id is null then
    return null;
  end if;

  select count(*)::int, max(v.created_at)
    into v_count, v_last
  from public.ventas v
  where v.tenant_id = v_tenant
    and not coalesce(v.anulada, false)
    and public.normalize_dni(v.cliente_dni) = v_row.dni_normalized;

  return jsonb_build_object(
    'id', v_row.id,
    'fullName', v_row.full_name,
    'dni', v_row.dni_normalized,
    'clu', v_row.clu,
    'cluExpiry', v_row.clu_expiry,
    'phone', v_row.phone,
    'email', v_row.email,
    'fiscalCondition', v_row.fiscal_condition,
    'address', v_row.address,
    'city', v_row.city,
    'notes', v_row.notes,
    'saleCount', coalesce(v_count, 0),
    'lastSaleAt', v_last
  );
end;
$$;

revoke all on function public.get_cliente_by_id(uuid) from public;
grant execute on function public.get_cliente_by_id(uuid) to authenticated;

commit;

notify pgrst, 'reload schema';
