-- AR-26: verificación permanente de privilegios efectivos por columna.
-- Falla (devuelve filas) si el privilegio efectivo NO coincide con lo declarado.
-- Correr en SQL Editor / CI de schema checks. Esperado: 0 filas.

-- 1. authenticated / anon NO deben poder escribir productos.stock
--    (el stock solo se mueve por RPC SECURITY DEFINER).
select 'productos.stock escribible por ' || grantee as violacion
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'productos'
  and column_name = 'stock'
  and privilege_type = 'UPDATE'
  and grantee in ('anon', 'authenticated')

union all

-- 2. anon / authenticated NO deben poder leer tenants.codigo_vendedores.
select 'tenants.codigo_vendedores legible por ' || grantee
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'tenants'
  and column_name = 'codigo_vendedores'
  and privilege_type = 'SELECT'
  and grantee in ('anon', 'authenticated')

union all

-- 3. productos.updated_at NO debe ser escribible (lo pone el trigger).
select 'productos.updated_at escribible por ' || grantee
from information_schema.column_privileges
where table_schema = 'public'
  and table_name = 'productos'
  and column_name = 'updated_at'
  and privilege_type in ('INSERT', 'UPDATE')
  and grantee in ('anon', 'authenticated');
