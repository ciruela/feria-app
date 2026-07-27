-- =====================================================================
-- Migracion 002 - Tienda web para clientes (storefront por tenant)
-- =====================================================================
--
-- Agrega:
--   - flag storefront_enabled en tenants (que armerias publican tienda)
--   - tabla pedidos (ordenes web de clientes finales)
--
-- El catalogo publico y la creacion de pedidos se sirven via Edge Functions
-- con service-role (supabase/functions/storefront-catalog y storefront-order),
-- NO por acceso anonimo directo, para mantener la RLS estricta.
-- =====================================================================

alter table public.tenants
  add column if not exists storefront_enabled boolean not null default false;

create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  cliente_nombre text not null default '',
  cliente_email text not null default '',
  cliente_telefono text not null default '',
  cliente_dni text not null default '',
  items jsonb not null,
  total_ars numeric(14, 2) not null default 0,
  total_usd numeric(12, 2) not null default 0,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'confirmado', 'entregado', 'cancelado')),
  pago_estado text not null default 'pendiente'
    check (pago_estado in ('pendiente', 'pagado', 'fallido')),
  pago_ref text not null default '',
  nota text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists pedidos_tenant_idx on public.pedidos (tenant_id, created_at);
create index if not exists pedidos_estado_idx on public.pedidos (tenant_id, estado);

-- RLS: el admin del tenant ve/gestiona sus pedidos; platform admin ve todo.
-- (La creacion del pedido desde la web publica pasa por Edge Function con
--  service-role, que hace bypass de RLS de forma controlada.)
alter table public.pedidos enable row level security;

drop policy if exists "pedidos_tenant" on public.pedidos;
create policy "pedidos_tenant" on public.pedidos
  for all
  using (tenant_id = public.current_tenant_id() or public.is_platform_admin())
  with check (tenant_id = public.current_tenant_id() or public.is_platform_admin());

-- Trigger de tenant_id por consistencia (los inserts del panel admin lo toman
-- del claim; la Edge Function lo setea explicitamente).
drop trigger if exists set_tenant_id_trg on public.pedidos;
create trigger set_tenant_id_trg
  before insert on public.pedidos
  for each row execute function public.set_tenant_id();
