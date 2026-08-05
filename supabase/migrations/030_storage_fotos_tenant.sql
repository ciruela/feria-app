-- =====================================================================
-- 030_storage_fotos_tenant.sql
-- ---------------------------------------------------------------------
-- AR-12 / PII-001: feria-fotos aceptaba subir/sobrescribir/enumerar/borrar
-- sin scope de tenant (y en runtime, policies podían ser aún más abiertas
-- que el repo). Se replica el patrón de 020 (feria-comprobantes):
--
--   - INSERT/UPDATE/DELETE: authenticated + prefijo tenant_id + manager.
--   - SELECT autenticado: solo objetos del tenant (anti-enumeración cross-tenant).
--   - Bucket sigue `public = true` para que el storefront/app lean por URL
--     pública `/object/public/...` sin listar el bucket.
--   - Límite de tamaño y mime types.
--
-- Path esperado (app): `<tenant_id>/<tipo>/<producto_id>/<ts>.jpg`
-- =====================================================================

begin;

-- 1. Límites del bucket (sigue público para URLs de producto).
update storage.buckets
   set public = true,
       file_size_limit = 5242880, -- 5 MiB
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
 where id = 'feria-fotos';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'feria-fotos',
  'feria-fotos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2. Tirar policies conocidas (repo + variantes típicas de Dashboard).
drop policy if exists "feria_fotos_public_read" on storage.objects;
drop policy if exists "feria_fotos_auth_upload" on storage.objects;
drop policy if exists "feria_fotos_auth_update" on storage.objects;
drop policy if exists "feria_fotos_auth_read" on storage.objects;
drop policy if exists "feria_fotos_auth_delete" on storage.objects;
drop policy if exists "feria_fotos_anon_upload" on storage.objects;
drop policy if exists "feria_fotos_anon_all" on storage.objects;
drop policy if exists "Give anon users access to feria-fotos" on storage.objects;
drop policy if exists "Allow public uploads" on storage.objects;
drop policy if exists "Public Access" on storage.objects;
drop policy if exists "feria_fotos_tenant_read" on storage.objects;
drop policy if exists "feria_fotos_tenant_insert" on storage.objects;
drop policy if exists "feria_fotos_tenant_update" on storage.objects;
drop policy if exists "feria_fotos_tenant_delete" on storage.objects;

-- 3. Lectura autenticada con scope de tenant (listado / signed).
--    Las URLs públicas del bucket siguen sirviendo el archivo sin esta policy.
create policy "feria_fotos_tenant_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'feria-fotos'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  );

-- 4. Escritura: solo gestores del tenant (no seller / no anon).
create policy "feria_fotos_tenant_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'feria-fotos'
    and (
      public.is_platform_admin()
      or (
        public.is_tenant_manager()
        and (storage.foldername(name))[1] = (public.current_tenant_id())::text
      )
    )
  );

create policy "feria_fotos_tenant_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'feria-fotos'
    and (
      public.is_platform_admin()
      or (
        public.is_tenant_manager()
        and (storage.foldername(name))[1] = (public.current_tenant_id())::text
      )
    )
  )
  with check (
    bucket_id = 'feria-fotos'
    and (
      public.is_platform_admin()
      or (
        public.is_tenant_manager()
        and (storage.foldername(name))[1] = (public.current_tenant_id())::text
      )
    )
  );

create policy "feria_fotos_tenant_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'feria-fotos'
    and (
      public.is_platform_admin()
      or (
        public.is_tenant_manager()
        and (storage.foldername(name))[1] = (public.current_tenant_id())::text
      )
    )
  );

commit;
