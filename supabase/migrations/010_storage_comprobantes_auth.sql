-- 010_storage_comprobantes_auth.sql
-- Permite subir/actualizar comprobantes PDF con sesión autenticada (no solo anon).
-- Sin esto, las ventas se registran pero pdf_path queda vacío al fallar storage.upload.

insert into storage.buckets (id, name, public)
values ('feria-comprobantes', 'feria-comprobantes', true)
on conflict (id) do update set public = true;

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
