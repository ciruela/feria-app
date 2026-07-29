-- 016_ventas_facturada.sql
-- Control de facturación AFIP: las chicas marcan qué comprobantes ya facturaron.

alter table public.ventas
  add column if not exists facturada boolean not null default false,
  add column if not exists facturada_at timestamptz,
  add column if not exists facturada_por text,
  add column if not exists factura_numero text;

create index if not exists ventas_tenant_facturada_idx
  on public.ventas (tenant_id, facturada, created_at desc);
