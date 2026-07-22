-- Políticas de Storage para bucket feria-fotos
-- Creá el bucket público "feria-fotos" en Dashboard → Storage antes de ejecutar.

insert into storage.buckets (id, name, public)
values ('feria-fotos', 'feria-fotos', true)
on conflict (id) do update set public = true;

drop policy if exists "feria_fotos_public_read" on storage.objects;
create policy "feria_fotos_public_read" on storage.objects
  for select using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_anon_upload" on storage.objects;
create policy "feria_fotos_anon_upload" on storage.objects
  for insert with check (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_anon_update" on storage.objects;
create policy "feria_fotos_anon_update" on storage.objects
  for update using (bucket_id = 'feria-fotos');

drop policy if exists "feria_fotos_anon_delete" on storage.objects;
create policy "feria_fotos_anon_delete" on storage.objects
  for delete using (bucket_id = 'feria-fotos');

-- Bucket comprobantes PDF
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
