-- DIAGNÓSTICO READ-ONLY (borrar). Prefijo no numérico => no registra versión.
with wg_paths as (
  select p.codigo, elem::text as foto_path
  from public.productos p,
       lateral jsonb_array_elements_text(to_jsonb(p.fotos)) elem
  where p.tenant_id = 'bfebd543-4aa8-43f7-9480-c3a128f08693'
    and p.activo
    and coalesce(jsonb_array_length(to_jsonb(p.fotos)), 0) > 0
)
select jsonb_pretty(jsonb_build_object(
  'wg_paths_total', (select count(*) from wg_paths),
  'wg_paths_con_objeto', (
    select count(*) from wg_paths w
    where exists (
      select 1 from storage.objects o
      where o.bucket_id = 'feria-fotos' and o.name = w.foto_path
    )
  ),
  'wg_paths_sin_objeto', (
    select jsonb_agg(w.foto_path) from wg_paths w
    where not exists (
      select 1 from storage.objects o
      where o.bucket_id = 'feria-fotos' and o.name = w.foto_path
    )
  ),
  'wg_objetos_sample', (
    select jsonb_agg(name order by name) from (
      select name from storage.objects
      where bucket_id = 'feria-fotos'
        and (storage.foldername(name))[1] = 'bfebd543-4aa8-43f7-9480-c3a128f08693'
      limit 8
    ) s
  )
)) as diag;
