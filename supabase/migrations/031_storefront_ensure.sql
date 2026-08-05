-- =====================================================================
-- 031_storefront_ensure.sql
-- ---------------------------------------------------------------------
-- AR-13: la migración 002 nunca se aplicó en QA (pedidos / storefront_enabled
-- ausentes). Esta migración es idempotente: asegura el esquema de tienda web
-- y policies por rol (alineadas a 027). Los pedidos públicos solo se crean
-- vía Edge Function con service-role (no insert anon directo).
-- =====================================================================

begin;

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
create index if not exists pedidos_email_created_idx
  on public.pedidos (tenant_id, cliente_email, created_at desc);

alter table public.pedidos enable row level security;

drop trigger if exists set_tenant_id_trg on public.pedidos;
create trigger set_tenant_id_trg
  before insert on public.pedidos
  for each row execute function public.set_tenant_id();

-- Policies: solo gestores del tenant (la Edge Function usa service-role).
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

revoke insert, update, delete on public.pedidos from anon;
grant select on public.pedidos to authenticated;

commit;

notify pgrst, 'reload schema';
