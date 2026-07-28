-- 014_storage_buckets.sql
-- Crea buckets de Storage y policies para usuarios autenticados (ventas PDF + fotos).
-- Aplicar en Supabase → SQL Editor si falla "bucket feria-comprobantes" al confirmar venta.
--
-- Si aparece "deadlock detected", usá 014_storage_buckets_steps.sql (3 runs separados)
-- o creá los buckets en Dashboard → Storage → New bucket y luego corré solo las policies.

-- ---------------------------------------------------------------------------
-- feria-comprobantes (PDFs de ventas)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('feria-comprobantes', 'feria-comprobantes', true)
on conflict (id) do update set public = true;

drop policy if exists "feria_comprobantes_public_read" on storage.objects;
create policy "feria_comprobantes_public_read" on storage.objects
  for select
  using (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_auth_upload" on storage.objects;
create policy "feria_comprobantes_auth_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_auth_update" on storage.objects;
create policy "feria_comprobantes_auth_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'feria-comprobantes')
  with check (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_auth_read" on storage.objects;
create policy "feria_comprobantes_auth_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'feria-comprobantes');

drop policy if exists "feria_comprobantes_auth_delete" on storage.objects;
create policy "feria_comprobantes_auth_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'feria-comprobantes');

-- ---------------------------------------------------------------------------
-- feria-fotos (imágenes de productos)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('feria-fotos', 'feria-fotos', true)
on conflict (id) do update set public = true;

drop policy if exists "feria_fotos_public_read" on storage.objects;
create policy "feria_fotos_public_read" on storage.objects
  for select
  using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_auth_upload" on storage.objects;
create policy "feria_fotos_auth_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_auth_update" on storage.objects;
create policy "feria_fotos_auth_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'feria-fotos')
  with check (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_auth_read" on storage.objects;
create policy "feria_fotos_auth_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_auth_delete" on storage.objects;
create policy "feria_fotos_auth_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'feria-fotos');
