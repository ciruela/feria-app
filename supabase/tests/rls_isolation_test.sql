-- =====================================================================
-- Test manual de aislamiento RLS entre tenants
-- =====================================================================
--
-- Verifica que un usuario de un tenant NO pueda ver datos de otro tenant.
-- Correr en el SQL Editor de Supabase DESPUES de aplicar 001_multitenant.sql
-- y la seccion "ACTIVAR RLS ESTRICTA".
--
-- Idea: simulamos el JWT de un usuario seteando el claim tenant_id via
-- request.jwt.claims y consultamos como rol `authenticated`.
-- =====================================================================

begin;

-- Dos tenants de prueba
insert into public.tenants (id, nombre, slug)
values
  ('11111111-1111-1111-1111-111111111111', 'Armeria A', 'test-a'),
  ('22222222-2222-2222-2222-222222222222', 'Armeria B', 'test-b')
on conflict (id) do nothing;

-- Un producto en cada tenant (bypaseamos trigger seteando tenant_id explicito
-- como rol dueno de la tabla; esto corre con privilegios del editor SQL)
insert into public.productos (id, type, marca, calibre, tenant_id)
values
  ('test-a-prod', 'municion', 'MarcaA', '9mm', '11111111-1111-1111-1111-111111111111'),
  ('test-b-prod', 'municion', 'MarcaB', '9mm', '22222222-2222-2222-2222-222222222222')
on conflict (id) do nothing;

-- Simular sesion del usuario del tenant A
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","tenant_id":"11111111-1111-1111-1111-111111111111","is_platform_admin":false}',
  true
);

-- Debe ver SOLO el producto del tenant A
select 'esperado 1 fila (solo test-a-prod)' as check;
select id, tenant_id from public.productos
where id in ('test-a-prod', 'test-b-prod');

-- Assert programatico: falla si ve el producto del tenant B
do $$
declare
  leak int;
begin
  select count(*) into leak from public.productos where id = 'test-b-prod';
  if leak > 0 then
    raise exception 'FALLO DE AISLAMIENTO: el tenant A ve datos del tenant B';
  end if;
  raise notice 'OK: aislamiento RLS correcto (tenant A no ve al B)';
end $$;

reset role;
rollback; -- no persistimos los datos de prueba
