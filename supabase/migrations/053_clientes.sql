-- =====================================================================
-- 053_clientes.sql
-- ---------------------------------------------------------------------
-- Base de clientes reutilizable por DNI/CUIT (autocompletado en checkout).
-- - Perfil único por tenant + DNI normalizado.
-- - Upsert automático al registrar venta (trigger en ventas).
-- - Lookup por DNI vía RPC (vendedores + gestores; sin SELECT PostgREST).
-- - Backfill desde ventas históricas.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- Tabla clientes
-- ---------------------------------------------------------------------

create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  dni_normalized text not null,
  full_name text not null default '',
  clu text not null default '',
  clu_expiry text not null default '',
  phone text not null default '',
  email text not null default '',
  fiscal_condition text not null default '',
  address text not null default '',
  city text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_sale_at timestamptz,
  sale_count int not null default 0,
  constraint clientes_tenant_dni_unique unique (tenant_id, dni_normalized)
);

create index if not exists clientes_tenant_dni_idx
  on public.clientes (tenant_id, dni_normalized);

alter table public.clientes enable row level security;

drop policy if exists "clientes_select" on public.clientes;

create policy "clientes_select" on public.clientes
  for select using (
    public.is_platform_admin()
    or (
      tenant_id = public.current_tenant_id()
      and public.is_tenant_manager()
    )
  );

revoke select, insert, update, delete on public.clientes from authenticated, anon;

-- ---------------------------------------------------------------------
-- Upsert interno (desde venta o backfill)
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
    now(),
    1
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
    last_sale_at = now(),
    sale_count = clientes.sale_count + 1,
    updated_at = now();
end;
$$;

revoke all on function public.upsert_cliente_from_sale(uuid, text, jsonb, text) from public;

-- ---------------------------------------------------------------------
-- Trigger: nueva venta → upsert cliente
-- ---------------------------------------------------------------------

create or replace function public.trg_ventas_upsert_cliente()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.anulada, false) then
    return new;
  end if;

  perform public.upsert_cliente_from_sale(
    new.tenant_id,
    new.cliente_dni,
    coalesce(new.items->'customer', '{}'::jsonb),
    new.cliente_nombre
  );

  return new;
end;
$$;

drop trigger if exists ventas_upsert_cliente on public.ventas;

create trigger ventas_upsert_cliente
  after insert on public.ventas
  for each row
  execute function public.trg_ventas_upsert_cliente();

-- ---------------------------------------------------------------------
-- Lookup por DNI (checkout / autocompletado)
-- ---------------------------------------------------------------------

create or replace function public.lookup_cliente_by_dni(p_dni text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant uuid := public.current_tenant_id();
  v_norm text := public.normalize_dni(p_dni);
  v_suffix text;
  v_row public.clientes%rowtype;
begin
  if v_tenant is null then
    raise exception 'tenant_required' using errcode = '42501';
  end if;
  perform public.require_tenant_actor();

  if length(v_norm) < 6 then
    return null;
  end if;

  v_suffix := right(v_norm, 4);

  select * into v_row
    from public.clientes c
   where c.tenant_id = v_tenant
     and c.dni_normalized = v_norm;

  insert into public.audit_log (
    tenant_id,
    actor_nombre,
    accion,
    entidad,
    entidad_id,
    detalle
  ) values (
    v_tenant,
    coalesce(auth.jwt()->>'email', auth.uid()::text, 'usuario'),
    'Consultó cliente por DNI',
    'cliente',
    coalesce(v_row.id::text, ''),
    format(
      'sufijo %s · %s',
      v_suffix,
      case when v_row.id is null then 'sin coincidencia' else 'encontrado' end
    )
  );

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'fullName', v_row.full_name,
    'dni', p_dni,
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

revoke all on function public.lookup_cliente_by_dni(text) from public;
grant execute on function public.lookup_cliente_by_dni(text) to authenticated;

-- ---------------------------------------------------------------------
-- Backfill desde ventas existentes (orden cronológico)
-- ---------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select
      v.tenant_id,
      v.cliente_dni,
      v.cliente_nombre,
      coalesce(v.items->'customer', '{}'::jsonb) as customer
    from public.ventas v
    where not coalesce(v.anulada, false)
      and length(public.normalize_dni(v.cliente_dni)) >= 6
    order by v.created_at asc
  loop
    perform public.upsert_cliente_from_sale(
      r.tenant_id,
      r.cliente_dni,
      r.customer,
      r.cliente_nombre
    );
  end loop;
end;
$$;

commit;

notify pgrst, 'reload schema';
