-- =====================================================================
-- 020_storage_comprobantes_private.sql
-- ---------------------------------------------------------------------
-- FIX (exposición de PII de ventas de armas):
--   1. El bucket `feria-comprobantes` era PÚBLICO: cualquiera con la URL
--      accedía al PDF (nombre, DNI, domicilio, CLU del cliente).
--   2. Las policies solo chequeaban `bucket_id`, así que CUALQUIER usuario
--      autenticado (incluido un vendedor anónimo de OTRA armería) podía
--      leer/actualizar/BORRAR cualquier comprobante de cualquier tenant.
--
-- Solución:
--   - Bucket privado (public = false). El acceso pasa por download autenticado
--     o URLs firmadas (signed URLs) desde la app.
--   - Policies con scope por tenant usando el prefijo del path. La app guarda
--     los comprobantes como `<tenant_id>/<año>/<mes>/<venta_id>.pdf`
--     (ver ComprobantePdfService.storagePath), así que la primera carpeta es
--     el tenant_id. Un usuario solo accede a los objetos de su tenant activo;
--     el platform admin accede a todos.
--
-- `feria-fotos` NO se toca: sigue público (son imágenes de producto, sin PII,
-- y las consume el storefront web sin login).
--
-- IMPORTANTE (datos legacy): comprobantes subidos ANTES de que el path llevara
-- prefijo de tenant quedan como `<año>/<mes>/<venta_id>.pdf` (sin tenant). Con
-- estas policies dejan de ser accesibles para admins de tenant (sí para el
-- platform admin). Si existieran, hay que migrarlos al prefijo del tenant.
-- Diagnóstico:
--   select name from storage.objects
--    where bucket_id = 'feria-comprobantes'
--      and (storage.foldername(name))[1] !~ '^[0-9a-f-]{36}$';
--
-- Compatibilidad con el flujo de venta: el vendedor (JWT con tenant_id) puede
-- subir/leer los comprobantes de SU tenant, así que registrar ventas desde el
-- portal sigue funcionando.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor (después de 010/014).
-- =====================================================================

begin;

-- 1. Bucket privado.
update storage.buckets set public = false where id = 'feria-comprobantes';

-- 2. Borrar policies abiertas previas (010 y 014).
drop policy if exists "feria_comprobantes_public_read"  on storage.objects;
drop policy if exists "feria_comprobantes_auth_read"    on storage.objects;
drop policy if exists "feria_comprobantes_auth_upload"  on storage.objects;
drop policy if exists "feria_comprobantes_auth_update"  on storage.objects;
drop policy if exists "feria_comprobantes_auth_delete"  on storage.objects;

-- 3. Policies con scope por tenant (primera carpeta del path = tenant_id).
create policy "feria_comprobantes_tenant_read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'feria-comprobantes'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  );

create policy "feria_comprobantes_tenant_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'feria-comprobantes'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  );

create policy "feria_comprobantes_tenant_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'feria-comprobantes'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  )
  with check (
    bucket_id = 'feria-comprobantes'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  );

create policy "feria_comprobantes_tenant_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'feria-comprobantes'
    and (
      public.is_platform_admin()
      or (storage.foldername(name))[1] = (public.current_tenant_id())::text
    )
  );

commit;
