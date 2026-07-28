-- Aplicar en Supabase SQL Editor — UN BLOQUE POR VEZ (Run).
-- Si ves "deadlock detected", esperá 10 s y reintentá el mismo bloque.
-- Cerrá la pestaña Storage del dashboard mientras corrés esto.

-- ========== PASO 1: solo buckets (Run) ==========
insert into storage.buckets (id, name, public)
values ('feria-comprobantes', 'feria-comprobantes', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('feria-fotos', 'feria-fotos', true)
on conflict (id) do update set public = true;

-- ========== PASO 2: policies feria-comprobantes (Run) ==========
drop policy if exists "feria_comprobantes_public_read" on storage.objects;
create policy "feria_comprobantes_public_read" on storage.objects
  for select using (bucket_id = 'feria-comprobantes');

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

-- ========== PASO 3: policies feria-fotos (Run) ==========
drop policy if exists "feria_fotos_public_read" on storage.objects;
create policy "feria_fotos_public_read" on storage.objects
  for select using (bucket_id = 'feria-fotos');

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
