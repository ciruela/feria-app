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
  updated_at timestamptz not null default now()
);

create index if not exists productos_type_idx on public.productos (type);
create index if not exists productos_marca_idx on public.productos (marca);

-- Vendedores
create table if not exists public.vendedores (
  id text primary key,
  nombre text not null,
  activo boolean not null default true,
  updated_at timestamptz not null default now()
);

-- Ventas (opcional, para historial)
create table if not exists public.ventas (
  id uuid primary key default gen_random_uuid(),
  vendedor_id text references public.vendedores (id),
  items jsonb not null,
  metodo_pago text not null,
  total_usd numeric(12, 2),
  total_ars numeric(14, 2),
  tipo_cambio numeric(12, 2),
  created_at timestamptz not null default now()
);

-- RLS: lectura/escritura para la app interna (anon key)
alter table public.productos enable row level security;
alter table public.vendedores enable row level security;
alter table public.ventas enable row level security;

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

-- Storage: crear bucket público "feria-fotos" desde Dashboard → Storage → New bucket
-- Marcar como Public. Subí las fotos ahí y guardá la URL pública en productos.foto_url.
