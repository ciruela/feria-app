-- 015_ventas_pdf_path.sql
-- Ruta del PDF del comprobante en Storage (bucket feria-comprobantes).

alter table public.ventas
  add column if not exists pdf_path text not null default '';
