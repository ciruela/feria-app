-- =====================================================================
-- 049_dolar_billete_como_efectivo.sql
-- ---------------------------------------------------------------------
-- Dólar billete / USD cotiza igual que efectivo (mismo % de descuento).
-- register_sale: unit_usd de dolar_billete = unit_ars / tipo_cambio.
-- =====================================================================

begin;

create or replace function public._sale_unit_ars(
  p_unit_usd numeric,
  p_rate numeric,
  p_method text,
  p_pricing jsonb,
  p_product_type text default null,
  p_calibre text default null,
  p_descripcion text default null
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
  v_src jsonb;
  v_mun jsonb;
  v_transfer_efectivo boolean := false;
  v_t3_solo_larga boolean := false;
  v_method text;
  v_is_municion boolean;
begin
  v_lista := p_unit_usd * p_rate;
  v_src := coalesce(p_pricing, '{}'::jsonb);
  v_is_municion := lower(coalesce(nullif(trim(p_product_type), ''), '')) = 'municion';
  v_mun := case
    when v_is_municion and jsonb_typeof(v_src->'municion') = 'object'
      then v_src->'municion'
    else null
  end;

  if v_mun is not null then
    v_efectivo := public._sale_clamp_pct(
      coalesce((v_mun->>'efectivo')::numeric, (v_src->>'efectivo')::numeric),
      5, 0, 30
    );
    v_transfer_efectivo := coalesce(
      (v_mun->>'transferencia_como_efectivo')::boolean,
      false
    );
    v_t3_solo_larga := coalesce(
      (v_mun->>'tarjeta3_solo_arma_larga')::boolean,
      true
    );
    if v_t3_solo_larga
       and not public._is_municion_arma_larga(p_calibre, p_descripcion) then
      v_t3 := public._sale_clamp_pct((v_src->>'tarjeta3')::numeric, 15, 0, 100);
    else
      v_t3 := public._sale_clamp_pct(
        coalesce((v_mun->>'tarjeta3')::numeric, (v_src->>'tarjeta3')::numeric),
        15, 0, 100
      );
    end if;
  else
    v_efectivo := public._sale_clamp_pct((v_src->>'efectivo')::numeric, 5, 0, 30);
    v_t3 := public._sale_clamp_pct((v_src->>'tarjeta3')::numeric, 15, 0, 100);
  end if;

  v_debito := public._sale_clamp_pct((v_src->>'debito')::numeric, 5, 0, 100);
  v_t1 := public._sale_clamp_pct((v_src->>'tarjeta1')::numeric, 10, 0, 100);
  v_t6 := public._sale_clamp_pct((v_src->>'tarjeta6')::numeric, 20, 0, 100);
  v_t9 := public._sale_clamp_pct((v_src->>'tarjeta9')::numeric, 30, 0, 100);
  v_t12 := public._sale_clamp_pct((v_src->>'tarjeta12')::numeric, 35, 0, 100);
  v_t18 := public._sale_clamp_pct((v_src->>'tarjeta18')::numeric, 45, 0, 100);

  v_method := coalesce(nullif(trim(p_method), ''), 'lista');

  return case v_method
    when 'efectivo' then v_lista * (1 - v_efectivo / 100)
    when 'dolar_billete' then v_lista * (1 - v_efectivo / 100)
    when 'transferencia' then
      case
        when v_transfer_efectivo then v_lista * (1 - v_efectivo / 100)
        else v_lista
      end
    when 'debito' then v_lista * (1 + v_debito / 100)
    when 'tarjeta1' then v_lista * (1 + v_t1 / 100)
    when 'tarjeta3' then v_lista * (1 + v_t3 / 100)
    when 'tarjeta6' then v_lista * (1 + v_t6 / 100)
    when 'tarjeta9' then v_lista * (1 + v_t9 / 100)
    when 'tarjeta12' then v_lista * (1 + v_t12 / 100)
    when 'tarjeta18' then v_lista * (1 + v_t18 / 100)
    else v_lista
  end;
end;
$$;

revoke all on function public._sale_unit_ars(numeric, numeric, text, jsonb, text, text, text)
  from public, anon, authenticated;

-- Solo el tramo de cotización: alinear unit_usd de dolar_billete con ARS efectivo.
-- Se reemplaza register_sale completo (misma firma que 048) con el ajuste.
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
  v_seller_claim text;
  v_vendedor text;
begin
  perform public.require_tenant_actor();

  v_tenant := public.current_tenant_id();
  v_seller_claim := nullif(trim(coalesce(auth.jwt()->>'seller_id', '')), '');
  if public.current_app_role() = 'seller' then
    v_vendedor := v_seller_claim;
  else
    v_vendedor := nullif(trim(coalesce(p_vendedor_id, '')), '');
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
    if v_qty <= 0 or v_qty > v_max_qty then
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
      descripcion,
      fixed_prices
      into v_producto
      from public.productos
     where id = v_product_id
       and tenant_id = v_tenant
     for update;

    if not found then
      raise exception 'product_not_found';
    end if;

    if public._sale_has_fixed_prices(v_producto.fixed_prices) then
      v_unit_usd := public._sale_unit_usd_fixed(
        v_producto.fixed_prices,
        coalesce(v_producto.precio_usd, 0)
      );
      v_unit_ars := public._sale_unit_ars_fixed(
        v_producto.fixed_prices,
        v_method
      );
    else
      v_unit_usd := coalesce(v_producto.precio_usd, 0);
      v_unit_ars := public._sale_unit_ars(
        v_unit_usd,
        v_rate,
        v_method,
        coalesce(p_pricing, '{}'::jsonb),
        v_producto.product_type,
        v_producto.calibre,
        v_producto.descripcion
      );
      -- USD billete = mismo descuento que efectivo (ARS/tipo de cambio).
      if v_method = 'dolar_billete' and v_rate > 0 then
        v_unit_usd := round(v_unit_ars / v_rate, 4);
      end if;
    end if;

    if v_unit_usd < 0 or v_unit_ars < 0 then
      raise exception 'invalid_price';
    end if;

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
            trim(concat_ws(
              ' · ',
              v_producto.marca,
              nullif(trim(v_producto.modelo), ''),
              nullif(trim(v_producto.calibre), '')
            ))
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
    v_vendedor,
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

  for v_pid in select key from jsonb_each(v_qty_by_product)
  loop
    perform public.apply_product_stock_delta(
      v_pid,
      -((v_qty_by_product->>v_pid)::integer),
      'venta',
      v_venta_id::text,
      v_vendedor,
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

revoke all on function public.register_sale(jsonb, text, text, text, text, text, jsonb) from public;
grant execute on function public.register_sale(jsonb, text, text, text, text, text, jsonb) to authenticated;

commit;
