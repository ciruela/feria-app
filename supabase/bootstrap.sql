-- Feria App — bootstrap completo (schema + vendedores)
-- Pegá TODO en Supabase Dashboard → SQL Editor → Run

-- === SCHEMA ===

create extension if not exists "pgcrypto";

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

create index if not exists productos_type_idx on public.productos (type);
create index if not exists productos_marca_idx on public.productos (marca);

create table if not exists public.vendedores (
  id text primary key,
  nombre text not null,
  activo boolean not null default true,
  updated_at timestamptz not null default now()
);

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

alter table public.ventas add column if not exists cliente_nombre text not null default '';
alter table public.ventas add column if not exists cliente_dni text not null default '';
alter table public.ventas add column if not exists pdf_path text not null default '';

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

alter table public.vendedores replica identity full;

alter table public.productos replica identity full;
alter table public.app_config replica identity full;

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

drop policy if exists "ventas_update" on public.ventas;
create policy "ventas_update" on public.ventas
  for update using (true) with check (true);

-- === SEED vendedores ===

insert into public.vendedores (id, nombre, activo) values
  ('v1', 'Agustín', true),
  ('v2', 'Carlos', true),
  ('v3', 'Diego', true),
  ('v4', 'Eduardo', true),
  ('v5', 'Fernando', true),
  ('v6', 'Gabriel', true),
  ('v7', 'Hernán', true),
  ('v8', 'Jorge', true),
  ('v9', 'Lucas', true),
  ('v10', 'Marcos', true),
  ('v11', 'Martín', true),
  ('v12', 'Pablo', true),
  ('v13', 'Ricardo', true),
  ('v14', 'Roberto', true),
  ('v15', 'Sebastián', true)
on conflict (id) do nothing;

-- === Storage bucket (opcional, si falla crearlo desde UI) ===

insert into storage.buckets (id, name, public)
values ('feria-fotos', 'feria-fotos', true)
on conflict (id) do update set public = true;

drop policy if exists "feria_fotos_public_read" on storage.objects;
create policy "feria_fotos_public_read" on storage.objects
  for select using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_anon_upload" on storage.objects;
create policy "feria_fotos_anon_upload" on storage.objects
  for insert with check (bucket_id = 'feria-fotos');

alter table public.productos add column if not exists fotos jsonb not null default '[]'::jsonb;

drop policy if exists "feria_fotos_anon_update" on storage.objects;
create policy "feria_fotos_anon_update" on storage.objects
  for update using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_anon_delete" on storage.objects;
create policy "feria_fotos_anon_delete" on storage.objects
  for delete using (bucket_id = 'feria-fotos');

insert into storage.buckets (id, name, public)
values ('feria-comprobantes', 'feria-comprobantes', true)
on conflict (id) do update set public = true;

drop policy if exists "feria_comprobantes_public_read" on storage.objects;
create policy "feria_comprobantes_public_read" on storage.objects
  for select using (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_anon_upload" on storage.objects;
create policy "feria_comprobantes_anon_upload" on storage.objects
  for insert with check (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_anon_update" on storage.objects;
create policy "feria_comprobantes_anon_update" on storage.objects
  for update using (bucket_id = 'feria-comprobantes');
