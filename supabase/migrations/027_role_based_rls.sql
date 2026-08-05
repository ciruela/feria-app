-- =====================================================================
-- 027_role_based_rls.sql
-- ---------------------------------------------------------------------
-- AR-9 / AUTH-001: las policies y RPCs leen auth.jwt()->>'app_role'.
--
-- Identidades de servidor (ya emitidas por el hook):
--   owner | admin  → gestores (membership)
--   seller         → portal de vendedores
--
-- El PIN Empleado/Administración de la app NO cambia el JWT; este
-- migration asegura que un seller no tenga el mismo poder que un owner.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Helpers de rol
-- ---------------------------------------------------------------------

create or replace function public.current_app_role()
returns text
language sql
stable
as $$
  select nullif(trim(coalesce(auth.jwt()->>'app_role', '')), '');
$$;

create or replace function public.is_tenant_manager()
returns boolean
language sql
stable
as $$
  select public.is_platform_admin()
      or public.current_app_role() in ('owner', 'admin');
$$;

create or replace function public.is_tenant_actor()
returns boolean
language sql
stable
as $$
  select public.is_platform_admin()
      or (
        public.current_tenant_id() is not null
        and public.current_app_role() in ('owner', 'admin', 'seller')
      );
$$;

create or replace function public.require_tenant_manager()
returns void
language plpgsql
stable
as $$
begin
  if public.current_tenant_id() is null and not public.is_platform_admin() then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  if not public.is_tenant_manager() then
    raise exception 'forbidden_role'
      using errcode = '42501',
            hint = 'Se requiere rol owner o admin';
  end if;
end;
$$;

create or replace function public.require_tenant_actor()
returns void
language plpgsql
stable
as $$
begin
  if not public.is_tenant_actor() then
    raise exception 'forbidden_role'
      using errcode = '42501',
            hint = 'Se requiere sesión de tenant (owner/admin/seller)';
  end if;
end;
$$;

grant execute on function public.current_app_role() to authenticated, anon;
grant execute on function public.is_tenant_manager() to authenticated, anon;
grant execute on function public.is_tenant_actor() to authenticated, anon;

-- ---------------------------------------------------------------------
-- administradores: solo gestores
-- ---------------------------------------------------------------------

drop policy if exists "administradores_tenant" on public.administradores;
drop policy if exists "administradores_select" on public.administradores;
drop policy if exists "administradores_insert" on public.administradores;
drop policy if exists "administradores_update" on public.administradores;
drop policy if exists "administradores_delete" on public.administradores;

create policy "administradores_select" on public.administradores
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "administradores_insert" on public.administradores
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "administradores_update" on public.administradores
  for update using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  )
  with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "administradores_delete" on public.administradores
  for delete using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- productos: lectura para actores; escritura solo gestores
-- ---------------------------------------------------------------------

drop policy if exists "productos_tenant" on public.productos;
drop policy if exists "productos_select" on public.productos;
drop policy if exists "productos_insert" on public.productos;
drop policy if exists "productos_update" on public.productos;
drop policy if exists "productos_delete" on public.productos;

create policy "productos_select" on public.productos
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_actor())
  );

create policy "productos_insert" on public.productos
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "productos_update" on public.productos
  for update using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  )
  with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "productos_delete" on public.productos
  for delete using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- vendedores: lectura actores; escritura gestores
-- ---------------------------------------------------------------------

drop policy if exists "vendedores_tenant" on public.vendedores;
drop policy if exists "vendedores_select" on public.vendedores;
drop policy if exists "vendedores_insert" on public.vendedores;
drop policy if exists "vendedores_update" on public.vendedores;
drop policy if exists "vendedores_delete" on public.vendedores;

create policy "vendedores_select" on public.vendedores
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_actor())
  );

create policy "vendedores_insert" on public.vendedores
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "vendedores_update" on public.vendedores
  for update using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  )
  with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "vendedores_delete" on public.vendedores
  for delete using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- app_config: lectura actores; escritura gestores
-- ---------------------------------------------------------------------

drop policy if exists "app_config_tenant" on public.app_config;
drop policy if exists "app_config_select" on public.app_config;
drop policy if exists "app_config_insert" on public.app_config;
drop policy if exists "app_config_update" on public.app_config;
drop policy if exists "app_config_delete" on public.app_config;

create policy "app_config_select" on public.app_config
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_actor())
  );

create policy "app_config_insert" on public.app_config
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "app_config_update" on public.app_config
  for update using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  )
  with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "app_config_delete" on public.app_config
  for delete using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- ventas: solo SELECT (writes vía RPC); cualquier actor del tenant
-- ---------------------------------------------------------------------

drop policy if exists "ventas_tenant" on public.ventas;
drop policy if exists "ventas_select" on public.ventas;

create policy "ventas_select" on public.ventas
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_actor())
  );

revoke insert, update, delete on public.ventas from authenticated, anon;
grant select on public.ventas to authenticated;

-- ---------------------------------------------------------------------
-- stock_movimientos / audit_log: endurecer con rol
-- ---------------------------------------------------------------------

drop policy if exists "stock_movimientos_select" on public.stock_movimientos;
create policy "stock_movimientos_select" on public.stock_movimientos
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_actor())
  );

drop policy if exists "audit_log_select" on public.audit_log;
drop policy if exists "audit_log_insert" on public.audit_log;

create policy "audit_log_select" on public.audit_log
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "audit_log_insert" on public.audit_log
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- pedidos (storefront): solo gestores
-- ---------------------------------------------------------------------

drop policy if exists "pedidos_tenant" on public.pedidos;
drop policy if exists "pedidos_select" on public.pedidos;
drop policy if exists "pedidos_insert" on public.pedidos;
drop policy if exists "pedidos_update" on public.pedidos;
drop policy if exists "pedidos_delete" on public.pedidos;

create policy "pedidos_select" on public.pedidos
  for select using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "pedidos_insert" on public.pedidos
  for insert with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "pedidos_update" on public.pedidos
  for update using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  )
  with check (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

create policy "pedidos_delete" on public.pedidos
  for delete using (
    public.is_platform_admin()
    or (tenant_id = public.current_tenant_id() and public.is_tenant_manager())
  );

-- ---------------------------------------------------------------------
-- Guards en RPCs sensibles
-- ---------------------------------------------------------------------

-- register_sale: owner | admin | seller
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
  -- Seller portal: forzar vendedor del JWT (no spoofear otro).
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

    v_unit_ars := public._sale_unit_ars(
      v_unit_usd, v_rate, v_method, coalesce(p_pricing, '{}'::jsonb)
    );
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

-- set_venta_pdf_path: cualquier actor (cierra comprobante de su venta)
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
  perform public.require_tenant_actor();
  v_tenant := public.current_tenant_id();

  v_path := nullif(trim(coalesce(p_path, '')), '');
  if v_path is null then
    raise exception 'pdf_path_required';
  end if;

  update public.ventas
     set pdf_path = left(v_path, 500)
   where id = p_venta_id
     and tenant_id = v_tenant
     and coalesce(anulada, false) = false
     and (
       public.is_tenant_manager()
       or public.current_app_role() <> 'seller'
       or vendedor_id is not distinct from nullif(trim(coalesce(auth.jwt()->>'seller_id', '')), '')
     );

  if not found then
    raise exception 'sale_not_found';
  end if;
end;
$$;

-- void_sale / set_venta_facturada / set_product_stock: solo gestores
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
  v_updated uuid;
begin
  perform public.require_tenant_manager();
  v_tenant := public.current_tenant_id();

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

  select coalesce(jsonb_object_agg(producto_id, qty), '{}'::jsonb)
    into v_qty_by_product
    from (
      select producto_id, (-sum(delta))::integer as qty
        from public.stock_movimientos
       where venta_id = p_venta_id
         and tenant_id = v_tenant
         and motivo = 'venta'
         and delta < 0
       group by producto_id
    ) movimientos;

  if v_qty_by_product = '{}'::jsonb then
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
  end if;

  update public.ventas
     set anulada = true,
         anulada_motivo = left(trim(p_motivo), 500),
         anulada_por = left(coalesce(p_actor_nombre, ''), 200),
         anulada_at = timezone('utc', now())
   where id = p_venta_id
     and tenant_id = v_tenant
     and coalesce(anulada, false) = false
  returning id into v_updated;

  if v_updated is null then
    return false;
  end if;

  for v_pid in select key from jsonb_each(v_qty_by_product)
  loop
    v_qty := (v_qty_by_product->>v_pid)::integer;
    if v_qty <= 0 then
      continue;
    end if;
    perform public.apply_product_stock_delta(
      v_pid,
      v_qty,
      'anulacion',
      p_venta_id::text,
      v_sale.vendedor_id,
      left(trim(p_motivo), 200)
    );
  end loop;

  return true;
end;
$$;

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
  perform public.require_tenant_manager();
  v_tenant := public.current_tenant_id();

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

create or replace function public.set_product_stock(
  p_product_id text,
  p_stock integer,
  p_motivo text default 'ajuste',
  p_nota text default ''
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current integer;
  v_next integer;
  v_delta integer;
  v_tenant uuid;
  v_motivo text;
begin
  perform public.require_tenant_manager();

  if p_stock is null or p_stock < 0 then
    raise exception 'invalid_stock';
  end if;

  v_motivo := coalesce(nullif(trim(p_motivo), ''), 'ajuste');
  if v_motivo not in ('carga', 'ajuste', 'venta', 'anulacion') then
    v_motivo := 'ajuste';
  end if;

  select stock, tenant_id
    into v_current, v_tenant
    from public.productos
   where id = p_product_id
     and (tenant_id = public.current_tenant_id() or public.is_platform_admin())
   for update;

  if not found then
    raise exception 'product_not_found';
  end if;

  v_next := p_stock;
  if v_current is not distinct from v_next then
    return v_next;
  end if;

  v_delta := v_next - coalesce(v_current, 0);
  perform set_config('app.stock_via_rpc', '1', true);

  update public.productos
     set stock = v_next,
         updated_at = now()
   where id = p_product_id;

  insert into public.stock_movimientos (
    producto_id, delta, motivo, stock_antes, stock_despues,
    venta_id, vendedor_id, nota, tenant_id
  ) values (
    p_product_id, v_delta, v_motivo, coalesce(v_current, 0), v_next,
    null, null, coalesce(p_nota, ''), v_tenant
  );

  return v_next;
end;
$$;

-- apply_product_stock_delta: solo vía otras RPC definer (no cliente directo)
revoke all on function public.apply_product_stock_delta(text, integer, text, text, text, text) from public;
revoke all on function public.apply_product_stock_delta(text, integer, text, text, text, text) from authenticated, anon;
-- El owner de la función (postgres/supabase_admin) sigue pudiendo ejecutarla
-- desde register_sale / void_sale / set_product_stock.

revoke all on function public.register_sale(jsonb, text, text, text, text, text, jsonb) from public;
grant execute on function public.register_sale(jsonb, text, text, text, text, text, jsonb) to authenticated;

revoke all on function public.set_venta_pdf_path(uuid, text) from public;
grant execute on function public.set_venta_pdf_path(uuid, text) to authenticated;

revoke all on function public.void_sale(uuid, text, text) from public;
grant execute on function public.void_sale(uuid, text, text) to authenticated;

revoke all on function public.set_venta_facturada(uuid, boolean, text, text) from public;
grant execute on function public.set_venta_facturada(uuid, boolean, text, text) to authenticated;

revoke all on function public.set_product_stock(text, integer, text, text) from public;
grant execute on function public.set_product_stock(text, integer, text, text) to authenticated;

commit;

notify pgrst, 'reload schema';
