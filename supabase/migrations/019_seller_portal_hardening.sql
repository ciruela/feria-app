-- =====================================================================
-- 019_seller_portal_hardening.sql
-- ---------------------------------------------------------------------
-- FIX (enumeración + fuerza bruta del portal de vendedores):
-- validate_seller_portal (grant a `anon`, definido en 012) devolvía mensajes
-- distintos para "dominio inexistente", "sin código configurado" y "clave
-- incorrecta". Eso permitía:
--   - Enumerar qué slugs/armerías existen.
--   - Distinguir cuándo el slug era válido para dirigir la fuerza bruta.
--
-- Solución: un único mensaje genérico ("Dominio o clave incorrectos") para los
-- tres casos, y computar el hash SIEMPRE para uniformar el tiempo de respuesta
-- (reduce el side-channel de timing). El resto (lista de vendedores tras clave
-- correcta) queda igual.
--
-- Nota: esto NO agrega rate limiting (no es trivial en SQL puro). El límite de
-- intentos conviene ponerlo a nivel de Edge Function / gateway más adelante.
--
-- Seguro de aplicar: el login legítimo del vendedor sigue funcionando idéntico;
-- solo cambian los mensajes de error.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor (después de 012).
-- =====================================================================

begin;

create or replace function public.validate_seller_portal(
  p_slug text,
  p_codigo text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant record;
  v_sellers jsonb;
  -- Se computa siempre (aunque el tenant no exista) para uniformar el timing.
  v_hash text := public.hash_portal_code(p_codigo);
begin
  select t.id, t.nombre, t.slug, t.codigo_vendedores
    into v_tenant
    from public.tenants t
   where lower(trim(t.slug)) = lower(trim(p_slug))
     and t.activo
   limit 1;

  -- Mensaje único e indistinguible para: dominio inexistente, sin código
  -- configurado, o clave incorrecta. Evita enumeración y dificulta el brute force.
  if v_tenant.id is null
     or coalesce(v_tenant.codigo_vendedores, '') = ''
     or v_hash <> v_tenant.codigo_vendedores then
    raise exception 'Dominio o clave incorrectos';
  end if;

  select coalesce(
           jsonb_agg(
             jsonb_build_object('id', v.id, 'nombre', v.nombre)
             order by v.nombre
           ),
           '[]'::jsonb
         )
    into v_sellers
    from public.vendedores v
   where v.tenant_id = v_tenant.id
     and v.activo;

  -- Este mensaje solo aparece TRAS validar la clave, así que no filtra info.
  if v_sellers = '[]'::jsonb then
    raise exception 'No hay vendedores activos en esta armería';
  end if;

  return jsonb_build_object(
    'tenant_id', v_tenant.id,
    'tenant_nombre', v_tenant.nombre,
    'tenant_slug', v_tenant.slug,
    'sellers', v_sellers
  );
end;
$$;

revoke all on function public.validate_seller_portal(text, text) from public;
grant execute on function public.validate_seller_portal(text, text) to anon, authenticated;

notify pgrst, 'reload schema';

commit;
