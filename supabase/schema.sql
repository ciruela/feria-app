-- Feria App — esquema Supabase
-- Ejecutá este script en: Supabase Dashboard → SQL Editor → New query

create extension if not exists "pgcrypto";

-- Productos del catálogo
create table if not exists public.productos (
  id text primary key,
  type text not null check (type in ('municion', 'arma_corta', 'arma_larga')),
  marca text not null,
  calibre text not null,
  codigo text not null default '',
  modelo text not null default '',
  precio_usd numeric(12, 2) not null default 0,
  foto text not null default '',
  foto_url text not null default '',
  stock integer,
  fotos jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.productos add column if not exists fotos jsonb not null default '[]'::jsonb;

-- Munición: saldo inicial (cajas), balas por caja y descripción interna
alter table public.productos add column if not exists stock_inicial integer;
alter table public.productos add column if not exists rounds_per_box integer;
alter table public.productos add column if not exists descripcion text not null default '';

create index if not exists productos_type_idx on public.productos (type);
create index if not exists productos_marca_idx on public.productos (marca);

-- Movimientos de stock (auditoría / trazabilidad)
create table if not exists public.stock_movimientos (
  id uuid primary key default gen_random_uuid(),
  producto_id text not null,
  delta integer not null,               -- +carga / -venta / ±ajuste (en cajas o unidades)
  motivo text not null,                 -- 'carga' | 'venta' | 'ajuste' | 'anulacion'
  stock_antes integer,
  stock_despues integer,
  venta_id uuid,
  vendedor_id text,
  nota text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists stock_mov_producto_idx
  on public.stock_movimientos (producto_id, created_at);
create index if not exists stock_mov_fecha_idx
  on public.stock_movimientos (created_at);

-- Vendedores
create table if not exists public.vendedores (
  id text primary key,
  nombre text not null,
  activo boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Administradores (identidad para auditoría; PIN propio por admin)
create table if not exists public.administradores (
  id text primary key,
  nombre text not null,
  pin text not null,
  activo boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Registro de actividad (auditoría de acciones de administradores)
create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id text,
  actor_nombre text not null default '',
  accion text not null,
  entidad text not null default '',
  entidad_id text not null default '',
  detalle text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists audit_log_fecha_idx on public.audit_log (created_at);
create index if not exists audit_log_actor_idx
  on public.audit_log (actor_id, created_at);
create index if not exists audit_log_entidad_idx
  on public.audit_log (entidad, created_at);

-- Ventas (historial de comprobantes)
create table if not exists public.ventas (
  id uuid primary key default gen_random_uuid(),
  vendedor_id text references public.vendedores (id),
  items jsonb not null,
  metodo_pago text not null,
  total_usd numeric(12, 2),
  total_ars numeric(14, 2),
  tipo_cambio numeric(12, 2),
  cliente_nombre text not null default '',
  cliente_dni text not null default '',
  pdf_path text not null default '',
  created_at timestamptz not null default now()
);

alter table public.ventas add column if not exists pdf_path text not null default '';

-- Migración: columnas de cliente en proyectos ya creados
alter table public.ventas add column if not exists cliente_nombre text not null default '';
alter table public.ventas add column if not exists cliente_dni text not null default '';

-- Anulación de ventas (soft-delete: la fila se conserva para auditoría)
alter table public.ventas add column if not exists anulada boolean not null default false;
alter table public.ventas add column if not exists anulada_motivo text not null default '';
alter table public.ventas add column if not exists anulada_por text not null default '';
alter table public.ventas add column if not exists anulada_at timestamptz;

-- Configuración global (tipo de cambio, etc.)
create table if not exists public.app_config (
  id text primary key,
  exchange_rate_ars numeric(12, 2) not null default 1500,
  updated_at timestamptz not null default now()
);

insert into public.app_config (id, exchange_rate_ars)
values ('global', 1500)
on conflict (id) do nothing;

alter table public.app_config enable row level security;

drop policy if exists "app_config_select" on public.app_config;
create policy "app_config_select" on public.app_config
  for select using (true);

drop policy if exists "app_config_write" on public.app_config;
create policy "app_config_write" on public.app_config
  for all using (true) with check (true);

-- Realtime: habilitar cambios en vivo (ejecutar una sola vez)
do $$
begin
  alter publication supabase_realtime add table public.productos;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.app_config;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.vendedores;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.administradores;
exception
  when duplicate_object then null;
end $$;

alter table public.administradores replica identity full;
alter table public.vendedores replica identity full;
alter table public.productos replica identity full;
alter table public.app_config replica identity full;

-- RLS: lectura/escritura para la app interna (anon key)
alter table public.productos enable row level security;
alter table public.vendedores enable row level security;
alter table public.ventas enable row level security;
alter table public.stock_movimientos enable row level security;
alter table public.administradores enable row level security;
alter table public.audit_log enable row level security;

drop policy if exists "administradores_select" on public.administradores;
create policy "administradores_select" on public.administradores
  for select using (true);

drop policy if exists "administradores_write" on public.administradores;
create policy "administradores_write" on public.administradores
  for all using (true) with check (true);

drop policy if exists "audit_log_select" on public.audit_log;
create policy "audit_log_select" on public.audit_log
  for select using (true);

drop policy if exists "audit_log_insert" on public.audit_log;
create policy "audit_log_insert" on public.audit_log
  for insert with check (true);

drop policy if exists "stock_mov_select" on public.stock_movimientos;
create policy "stock_mov_select" on public.stock_movimientos
  for select using (true);

drop policy if exists "stock_mov_insert" on public.stock_movimientos;
create policy "stock_mov_insert" on public.stock_movimientos
  for insert with check (true);

drop policy if exists "productos_select" on public.productos;
create policy "productos_select" on public.productos
  for select using (true);

drop policy if exists "productos_write" on public.productos;
create policy "productos_write" on public.productos
  for all using (true) with check (true);

drop policy if exists "vendedores_select" on public.vendedores;
create policy "vendedores_select" on public.vendedores
  for select using (true);

drop policy if exists "vendedores_write" on public.vendedores;
create policy "vendedores_write" on public.vendedores
  for all using (true) with check (true);

drop policy if exists "ventas_select" on public.ventas;
create policy "ventas_select" on public.ventas
  for select using (true);

drop policy if exists "ventas_insert" on public.ventas;
create policy "ventas_insert" on public.ventas
  for insert with check (true);

drop policy if exists "ventas_update" on public.ventas;
create policy "ventas_update" on public.ventas
  for update using (true) with check (true);

-- Storage: ver supabase/SETUP.md para crear el bucket feria-fotos
