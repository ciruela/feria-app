-- =====================================================================
-- 054_clientes_admin_rpc.sql
-- ---------------------------------------------------------------------
-- RPCs de gestión de clientes para panel admin (listado, detalle, edición).
-- Sin SELECT PostgREST directo sobre clientes.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Listado con búsqueda (nombre, teléfono, mail, DNI parcial)
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
      'saleCount', c.sale_count,
      'lastSaleAt', c.last_sale_at
    )
    from public.clientes c
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
    order by c.last_sale_at desc nulls last, c.full_name asc
    limit v_limit;
end;
$$;

revoke all on function public.list_clientes(text, int) from public;
grant execute on function public.list_clientes(text, int) to authenticated;

-- ---------------------------------------------------------------------
-- Detalle por id
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
    'saleCount', v_row.sale_count,
    'lastSaleAt', v_row.last_sale_at
  );
end;
$$;

revoke all on function public.get_cliente_by_id(uuid) from public;
grant execute on function public.get_cliente_by_id(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Edición manual (DNI inmutable; contadores server-side)
-- ---------------------------------------------------------------------

create or replace function public.update_cliente(
  p_id uuid,
  p_customer jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_c jsonb := coalesce(p_customer, '{}'::jsonb);
  v_updated int;
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_manager();

  if p_id is null then
    raise exception 'cliente_id_required' using errcode = '22023';
  end if;

  update public.clientes c
     set full_name = left(coalesce(nullif(trim(v_c->>'fullName'), ''), c.full_name), 200),
         clu = left(coalesce(nullif(trim(v_c->>'clu'), ''), c.clu), 80),
         clu_expiry = left(coalesce(nullif(trim(v_c->>'cluExpiry'), ''), c.clu_expiry), 20),
         phone = left(coalesce(nullif(trim(v_c->>'phone'), ''), c.phone), 40),
         email = left(coalesce(nullif(trim(v_c->>'email'), ''), c.email), 120),
         fiscal_condition = left(
           coalesce(nullif(trim(v_c->>'fiscalCondition'), ''), c.fiscal_condition),
           80
         ),
         address = left(coalesce(nullif(trim(v_c->>'address'), ''), c.address), 200),
         city = left(coalesce(nullif(trim(v_c->>'city'), ''), c.city), 80),
         notes = left(coalesce(nullif(trim(v_c->>'notes'), ''), c.notes), 500),
         updated_at = now()
   where c.tenant_id = v_tenant
     and c.id = p_id;

  get diagnostics v_updated = row_count;

  if v_updated = 0 then
    return false;
  end if;

  insert into public.audit_log (
    tenant_id,
    actor_nombre,
    accion,
    entidad,
    entidad_id,
    detalle
  ) values (
    v_tenant,
    coalesce(auth.jwt()->>'email', auth.uid()::text, 'gestor'),
    'Editó cliente',
    'cliente',
    p_id::text,
    left(coalesce(nullif(trim(v_c->>'fullName'), ''), ''), 80)
  );

  return true;
end;
$$;

revoke all on function public.update_cliente(uuid, jsonb) from public;
grant execute on function public.update_cliente(uuid, jsonb) to authenticated;

commit;

notify pgrst, 'reload schema';
