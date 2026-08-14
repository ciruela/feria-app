-- Seed mínimo para feria-app-staging (sin PII de prod).
-- Correr: PROJECT_REF=edwpfzdhitlnvewubebx ./scripts/apply_supabase_migration.sh supabase/seeds/staging_demo.sql
-- Después: crear usuario en Auth (dashboard) e insertar membership (ver abajo).

begin;

insert into public.tenants (id, nombre, slug, activo, plan)
values (
  'aaaaaaaa-bbbb-cccc-dddd-000000000001',
  'Armería Staging',
  'staging-demo',
  true,
  'basico'
)
on conflict (slug) do nothing;

insert into public.app_config (
  id,
  tenant_id,
  exchange_rate_ars,
  updated_at
) values (
  'global',
  'aaaaaaaa-bbbb-cccc-dddd-000000000001',
  1200,
  now()
)
on conflict (id, tenant_id) do update
  set exchange_rate_ars = excluded.exchange_rate_ars,
      updated_at = now();

insert into public.vendedores (id, nombre, activo, tenant_id)
values
  ('v-staging-1', 'VENDEDOR DEMO', true, 'aaaaaaaa-bbbb-cccc-dddd-000000000001')
on conflict do nothing;

insert into public.productos (
  id,
  codigo,
  modelo,
  calibre,
  descripcion,
  marca,
  precio_usd,
  stock,
  tenant_id,
  type,
  activo
) values
  (
    'p-staging-1',
    'DEMO-001',
    'PISTOLA DEMO',
    '9MM',
    'Producto de prueba staging',
    'DEMO',
    500,
    10,
    'aaaaaaaa-bbbb-cccc-dddd-000000000001',
    'arma_corta',
    true
  )
on conflict do nothing;

-- Cliente de prueba para lookup en checkout
insert into public.clientes (
  tenant_id,
  dni_normalized,
  full_name,
  clu,
  phone,
  address,
  city,
  sale_count
) values (
  'aaaaaaaa-bbbb-cccc-dddd-000000000001',
  '30123456',
  'CLIENTE DEMO STAGING',
  '123456',
  '1112345678',
  'CALLE FALSA 123',
  'CABA',
  2
)
on conflict (tenant_id, dni_normalized) do update
  set full_name = excluded.full_name,
      phone = excluded.phone;

commit;

-- Membership (ejecutar manualmente tras crear user en Auth → Users):
-- insert into public.memberships (user_id, tenant_id, rol, nombre, activo)
-- values ('<AUTH_USER_UUID>', 'aaaaaaaa-bbbb-cccc-dddd-000000000001', 'owner', 'Admin Staging', true);
