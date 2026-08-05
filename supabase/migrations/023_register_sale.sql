-- =====================================================================
-- 023_register_sale.sql
-- ---------------------------------------------------------------------
-- AR-5 / AR-10: el total de la venta ya no lo fija el cliente.
--
-- 1) RPC register_sale (security definer): recalcula unit/line/totales
--    desde productos.precio_usd + app_config.exchange_rate_ars, inserta
--    ventas y descuenta stock (apply_product_stock_delta) en una sola TX.
-- 2) RPCs auxiliares para pdf / anulación / facturada (ya no hay UPDATE
--    directo sobre ventas).
-- 3) Defensa: CHECK de importes >= 0, idempotency_key, revoke
--    insert/update/delete on ventas from authenticated|anon.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------

alter table public.ventas
  add column if not exists idempotency_key text;

create unique index if not exists ventas_tenant_idempotency_uidx
  on public.ventas (tenant_id, idempotency_key)
  where idempotency_key is not null;

alter table public.ventas
  drop constraint if exists ventas_total_usd_nonneg;
alter table public.ventas
  add constraint ventas_total_usd_nonneg
  check (total_usd is null or total_usd >= 0);

alter table public.ventas
  drop constraint if exists ventas_total_ars_nonneg;
alter table public.ventas
  add constraint ventas_total_ars_nonneg
  check (total_ars is null or total_ars >= 0);

alter table public.ventas
  drop constraint if exists ventas_tipo_cambio_positive;
alter table public.ventas
  add constraint ventas_tipo_cambio_positive
  check (tipo_cambio is null or tipo_cambio > 0);

-- ---------------------------------------------------------------------
-- Helpers de pricing (defaults alineados a PricingSettingsService)
-- ---------------------------------------------------------------------

create or replace function public._sale_clamp_pct(
  p_value numeric,
  p_default numeric,
  p_min numeric,
  p_max numeric
) returns numeric
language sql
immutable
as $$
  select least(p_max, greatest(p_min, coalesce(p_value, p_default)));
$$;

create or replace function public._sale_unit_ars(
  p_unit_usd numeric,
  p_rate numeric,
  p_method text,
  p_pricing jsonb
) returns numeric
language plpgsql
stable
as $$
declare
  v_lista numeric;
  v_efectivo numeric;
  v_debito numeric;
  v_t1 numeric;
  v_t3 numeric;
  v_t6 numeric;
  v_t9 numeric;
  v_t12 numeric;
  v_t18 numeric;
begin
  v_lista := p_unit_usd * p_rate;
  v_efectivo := public._sale_clamp_pct((p_pricing->>'efectivo')::numeric, 5, 0, 30);
  v_debito := public._sale_clamp_pct((p_pricing->>'debito')::numeric, 5, 0, 100);
  v_t1 := public._sale_clamp_pct((p_pricing->>'tarjeta1')::numeric, 10, 0, 100);
  v_t3 := public._sale_clamp_pct((p_pricing->>'tarjeta3')::numeric, 15, 0, 100);
  v_t6 := public._sale_clamp_pct((p_pricing->>'tarjeta6')::numeric, 20, 0, 100);
  v_t9 := public._sale_clamp_pct((p_pricing->>'tarjeta9')::numeric, 30, 0, 100);
  v_t12 := public._sale_clamp_pct((p_pricing->>'tarjeta12')::numeric, 35, 0, 100);
  v_t18 := public._sale_clamp_pct((p_pricing->>'tarjeta18')::numeric, 45, 0, 100);

  return case coalesce(nullif(trim(p_method), ''), 'lista')
    when 'efectivo' then v_lista * (1 - v_efectivo / 100)
    when 'debito' then v_lista * (1 + v_debito / 100)
    when 'tarjeta1' then v_lista * (1 + v_t1 / 100)
    when 'tarjeta3' then v_lista * (1 + v_t3 / 100)
    when 'tarjeta6' then v_lista * (1 + v_t6 / 100)
    when 'tarjeta9' then v_lista * (1 + v_t9 / 100)
    when 'tarjeta12' then v_lista * (1 + v_t12 / 100)
    when 'tarjeta18' then v_lista * (1 + v_t18 / 100)
    else v_lista -- lista / transferencia / dolar_billete (ARS ref)
  end;
end;
$$;

-- ---------------------------------------------------------------------
-- register_sale
-- ---------------------------------------------------------------------

create or replace function public.register_sale(
  p_items jsonb,
  p_metodo_pago text default 'lista',
  p_cliente_nombre text default '',
  p_cliente_dni text default '',
  p_vendedor_id text default null,
  p_idempotency_key text default null,
  p_pricing jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_rate numeric;
  v_existing uuid;
  v_idem text;
  v_lines jsonb;
  v_line jsonb;
  v_product_id text;
  v_qty integer;
  v_method text;
  v_pricing_method text;
  v_unit_usd numeric;
  v_unit_ars numeric;
  v_line_usd numeric;
  v_line_ars numeric;
  v_catalog_usd numeric := 0;
  v_catalog_ars numeric := 0;
  v_total_usd numeric := 0;
  v_total_ars numeric := 0;
  v_built_lines jsonb := '[]'::jsonb;
  v_items jsonb;
  v_qty_by_product jsonb := '{}'::jsonb;
  v_pid text;
  v_producto record;
  v_alloc jsonb;
  v_allocs jsonb;
  v_share numeric;
  v_share_sum numeric := 0;
  v_method_keys text[];
  v_venta_id uuid;
  v_idx integer := 0;
  v_max_lines constant integer := 200;
  v_max_qty constant integer := 9999;
begin
  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required';
  end if;

  v_idem := nullif(trim(coalesce(p_idempotency_key, '')), '');
  if v_idem is not null then
    select id into v_existing
      from public.ventas
     where tenant_id = v_tenant
       and idempotency_key = v_idem;
    if found then
      return jsonb_build_object(
        'id', v_existing,
        'idempotent', true
      );
    end if;
  end if;

  select exchange_rate_ars into v_rate
    from public.app_config
   where id = 'global'
     and tenant_id = v_tenant;

  if v_rate is null or v_rate <= 0 then
    raise exception 'exchange_rate_missing';
  end if;

  v_lines := coalesce(p_items->'lines', '[]'::jsonb);
  if jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) = 0 then
    raise exception 'items_required';
  end if;
  if jsonb_array_length(v_lines) > v_max_lines then
    raise exception 'too_many_items';
  end if;

  -- Método de pricing de las líneas (todas usan el mismo en el cliente).
  v_pricing_method := coalesce(
    nullif(trim(v_lines->0->>'paymentMethod'), ''),
    nullif(trim(split_part(coalesce(p_metodo_pago, ''), ',', 1)), ''),
    'lista'
  );

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_idx := v_idx + 1;
    v_product_id := nullif(trim(coalesce(v_line->>'productId', '')), '');
    if v_product_id is null then
      raise exception 'product_required';
    end if;

    v_qty := floor(coalesce((v_line->>'quantity')::numeric, 0));
    if v_qty <= 0 then
      raise exception 'invalid_quantity';
    end if;
    if v_qty > v_max_qty then
      raise exception 'invalid_quantity';
    end if;

    v_method := coalesce(
      nullif(trim(v_line->>'paymentMethod'), ''),
      v_pricing_method
    );

    select
      id,
      precio_usd,
      stock,
      marca,
      modelo,
      codigo,
      "type" as product_type,
      calibre,
      descripcion
      into v_producto
      from public.productos
     where id = v_product_id
       and tenant_id = v_tenant
     for update;

    if not found then
      raise exception 'product_not_found';
    end if;

    v_unit_usd := coalesce(v_producto.precio_usd, 0);
    if v_unit_usd < 0 then
      raise exception 'invalid_price';
    end if;

    v_unit_ars := public._sale_unit_ars(v_unit_usd, v_rate, v_method, coalesce(p_pricing, '{}'::jsonb));
    v_line_usd := v_unit_usd * v_qty;
    v_line_ars := v_unit_ars * v_qty;
    v_catalog_usd := v_catalog_usd + v_line_usd;
    v_catalog_ars := v_catalog_ars + v_line_ars;

    v_qty_by_product := jsonb_set(
      v_qty_by_product,
      array[v_product_id],
      to_jsonb(coalesce((v_qty_by_product->>v_product_id)::integer, 0) + v_qty)
    );

    v_built_lines := v_built_lines || jsonb_build_array(
      jsonb_strip_nulls(
        jsonb_build_object(
          'productId', v_producto.id,
          'productType', coalesce(
            nullif(trim(v_line->>'productType'), ''),
            v_producto.product_type
          ),
          'code', coalesce(
            nullif(trim(v_line->>'code'), ''),
            nullif(trim(v_producto.codigo), ''),
            v_producto.id
          ),
          'quantity', v_qty,
          'detail', coalesce(
            nullif(trim(v_line->>'detail'), ''),
            trim(concat_ws(' · ', v_producto.marca, nullif(trim(v_producto.modelo), ''), nullif(trim(v_producto.calibre), '')))
          ),
          'unitArs', round(v_unit_ars, 2),
          'lineArs', round(v_line_ars, 2),
          'unitUsd', round(v_unit_usd, 4),
          'lineUsd', round(v_line_usd, 4),
          'paymentMethod', v_method,
          'isArma', coalesce(
            (v_line->>'isArma')::boolean,
            v_producto.product_type in ('arma_corta', 'arma_larga')
          ),
          'serialNumber', coalesce(v_line->>'serialNumber', ''),
          'tarjetaConsumo', coalesce(v_line->>'tarjetaConsumo', ''),
          'splitPart', v_line->'splitPart'
        )
      )
    );
  end loop;

  -- Totales contables: según medio de cobro (como Budget.totalUsdLines/ArsLines).
  v_allocs := coalesce(p_items->'allocations', '[]'::jsonb);
  if jsonb_typeof(v_allocs) = 'array' and jsonb_array_length(v_allocs) > 0 then
    for v_alloc in select value from jsonb_array_elements(v_allocs)
    loop
      v_share := coalesce((v_alloc->>'share')::numeric, 0);
      if v_share < 0 or v_share > 1 then
        raise exception 'invalid_allocation_share';
      end if;
      v_share_sum := v_share_sum + v_share;
      v_method := coalesce(nullif(trim(v_alloc->>'method'), ''), v_pricing_method);
      if v_method = 'dolar_billete' then
        v_total_usd := v_total_usd + round(v_catalog_usd * v_share, 4);
      else
        v_total_ars := v_total_ars + round(v_catalog_ars * v_share, 2);
      end if;
    end loop;
    if abs(v_share_sum - 1) > 0.001 then
      raise exception 'invalid_allocation_share';
    end if;
  else
    if v_pricing_method = 'dolar_billete' then
      v_total_usd := round(v_catalog_usd, 4);
      v_total_ars := 0;
    else
      v_total_usd := 0;
      v_total_ars := round(v_catalog_ars, 2);
    end if;
  end if;

  if v_total_usd < 0 or v_total_ars < 0 then
    raise exception 'invalid_totals';
  end if;

  v_method_keys := string_to_array(
    regexp_replace(coalesce(nullif(trim(p_metodo_pago), ''), v_pricing_method), '\s+', '', 'g'),
    ','
  );

  v_items := jsonb_build_object(
    'customer', coalesce(p_items->'customer', '{}'::jsonb),
    'lines', v_built_lines,
    'sellerName', p_items->>'sellerName',
    'date', coalesce(p_items->>'date', timezone('utc', now())::text),
    'allocations', case
      when jsonb_typeof(v_allocs) = 'array' and jsonb_array_length(v_allocs) > 0
        then (
          select coalesce(jsonb_agg(
            jsonb_build_object(
              'method', coalesce(nullif(trim(a->>'method'), ''), v_pricing_method),
              'amountUsd', case
                when coalesce(nullif(trim(a->>'method'), ''), v_pricing_method) = 'dolar_billete'
                  then round(v_catalog_usd * coalesce((a->>'share')::numeric, 0), 4)
                else 0
              end,
              'amountArs', case
                when coalesce(nullif(trim(a->>'method'), ''), v_pricing_method) = 'dolar_billete'
                  then 0
                else round(v_catalog_ars * coalesce((a->>'share')::numeric, 0), 2)
              end,
              'share', coalesce((a->>'share')::numeric, 0)
            )
          ), '[]'::jsonb)
          from jsonb_array_elements(v_allocs) a
        )
      else '[]'::jsonb
    end
  );

  insert into public.ventas (
    vendedor_id,
    items,
    metodo_pago,
    total_usd,
    total_ars,
    tipo_cambio,
    cliente_nombre,
    cliente_dni,
    tenant_id,
    idempotency_key
  ) values (
    nullif(trim(coalesce(p_vendedor_id, '')), ''),
    v_items,
    array_to_string(v_method_keys, ', '),
    v_total_usd,
    v_total_ars,
    v_rate,
    left(coalesce(p_cliente_nombre, ''), 200),
    left(coalesce(p_cliente_dni, ''), 40),
    v_tenant,
    v_idem
  )
  returning id into v_venta_id;

  -- Stock atómico por producto (AR-10).
  for v_pid in select key from jsonb_each(v_qty_by_product)
  loop
    perform public.apply_product_stock_delta(
      v_pid,
      -((v_qty_by_product->>v_pid)::integer),
      'venta',
      v_venta_id::text,
      nullif(trim(coalesce(p_vendedor_id, '')), ''),
      ''
    );
  end loop;

  return jsonb_build_object(
    'id', v_venta_id,
    'total_usd', v_total_usd,
    'total_ars', v_total_ars,
    'tipo_cambio', v_rate,
    'items', v_items,
    'idempotent', false
  );
end;
$$;

-- ---------------------------------------------------------------------
-- set_venta_pdf_path
-- ---------------------------------------------------------------------

create or replace function public.set_venta_pdf_path(
  p_venta_id uuid,
  p_path text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_path text;
begin
  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required';
  end if;

  v_path := nullif(trim(coalesce(p_path, '')), '');
  if v_path is null then
    raise exception 'pdf_path_required';
  end if;

  update public.ventas
     set pdf_path = left(v_path, 500)
   where id = p_venta_id
     and tenant_id = v_tenant
     and coalesce(anulada, false) = false;

  if not found then
    raise exception 'sale_not_found';
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- void_sale (anulación + restitución de stock)
-- ---------------------------------------------------------------------

create or replace function public.void_sale(
  p_venta_id uuid,
  p_motivo text,
  p_actor_nombre text default ''
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_sale record;
  v_line jsonb;
  v_qty_by_product jsonb := '{}'::jsonb;
  v_pid text;
  v_qty integer;
begin
  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required';
  end if;

  if nullif(trim(coalesce(p_motivo, '')), '') is null then
    raise exception 'motivo_required';
  end if;

  select id, anulada, items, vendedor_id
    into v_sale
    from public.ventas
   where id = p_venta_id
     and tenant_id = v_tenant
   for update;

  if not found then
    return false;
  end if;
  if coalesce(v_sale.anulada, false) then
    return false;
  end if;

  for v_line in
    select value from jsonb_array_elements(coalesce(v_sale.items->'lines', '[]'::jsonb))
  loop
    v_pid := nullif(trim(coalesce(v_line->>'productId', '')), '');
    v_qty := floor(coalesce((v_line->>'quantity')::numeric, 0));
    if v_pid is null or v_qty <= 0 then
      continue;
    end if;
    v_qty_by_product := jsonb_set(
      v_qty_by_product,
      array[v_pid],
      to_jsonb(coalesce((v_qty_by_product->>v_pid)::integer, 0) + v_qty)
    );
  end loop;

  update public.ventas
     set anulada = true,
         anulada_motivo = left(trim(p_motivo), 500),
         anulada_por = left(coalesce(p_actor_nombre, ''), 200),
         anulada_at = timezone('utc', now())
   where id = p_venta_id
     and tenant_id = v_tenant;

  for v_pid in select key from jsonb_each(v_qty_by_product)
  loop
    perform public.apply_product_stock_delta(
      v_pid,
      (v_qty_by_product->>v_pid)::integer,
      'anulacion',
      p_venta_id::text,
      v_sale.vendedor_id,
      left(trim(p_motivo), 200)
    );
  end loop;

  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- set_venta_facturada
-- ---------------------------------------------------------------------

create or replace function public.set_venta_facturada(
  p_venta_id uuid,
  p_facturada boolean,
  p_factura_numero text default '',
  p_actor_nombre text default ''
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid;
  v_anulada boolean;
begin
  v_tenant := public.current_tenant_id();
  if v_tenant is null then
    raise exception 'tenant_required';
  end if;

  select coalesce(anulada, false) into v_anulada
    from public.ventas
   where id = p_venta_id
     and tenant_id = v_tenant
   for update;

  if not found then
    return false;
  end if;
  if v_anulada then
    return false;
  end if;

  if p_facturada then
    update public.ventas
       set facturada = true,
           facturada_at = timezone('utc', now()),
           facturada_por = left(coalesce(p_actor_nombre, ''), 200),
           factura_numero = left(trim(coalesce(p_factura_numero, '')), 80)
     where id = p_venta_id
       and tenant_id = v_tenant;
  else
    update public.ventas
       set facturada = false,
           facturada_at = null,
           facturada_por = '',
           factura_numero = ''
     where id = p_venta_id
       and tenant_id = v_tenant;
  end if;

  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------

revoke all on function public._sale_clamp_pct(numeric, numeric, numeric, numeric) from public;
revoke all on function public._sale_unit_ars(numeric, numeric, text, jsonb) from public;
revoke all on function public.register_sale(jsonb, text, text, text, text, text, jsonb) from public;
revoke all on function public.set_venta_pdf_path(uuid, text) from public;
revoke all on function public.void_sale(uuid, text, text) from public;
revoke all on function public.set_venta_facturada(uuid, boolean, text, text) from public;

grant execute on function public.register_sale(jsonb, text, text, text, text, text, jsonb) to authenticated;
grant execute on function public.set_venta_pdf_path(uuid, text) to authenticated;
grant execute on function public.void_sale(uuid, text, text) to authenticated;
grant execute on function public.set_venta_facturada(uuid, boolean, text, text) to authenticated;

-- Cierra el INSERT/UPDATE/DELETE directo (PostgREST). SELECT sigue por RLS.
revoke insert, update, delete on public.ventas from authenticated, anon;

commit;

notify pgrst, 'reload schema';
