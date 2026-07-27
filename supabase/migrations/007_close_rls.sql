-- =====================================================================
-- 007_close_rls.sql — Cierre de RLS estricta por tenant (aplicado en prod)
-- ---------------------------------------------------------------------
-- Contexto: las migraciones previas dejaron RLS habilitada pero con
-- policies abiertas `using (true)` (el bloque estricto de 001 nunca se
-- había corrido). Esto reemplaza esas policies por policies por tenant,
-- de modo que un cliente solo ve/escribe filas de su propio tenant
-- (o todo, si es platform admin).
--
-- Precondiciones verificadas antes de aplicar:
--   - Funciones current_tenant_id(), is_platform_admin() presentes.
--   - Trigger set_tenant_id_trg (BEFORE INSERT) en todas las tablas.
--   - Sin filas con tenant_id NULL (backfill de audit_log incluido abajo).
--   - Hook custom_access_token_hook activo (el JWT trae tenant_id).
-- Verificación posterior: REST con anon key devuelve [] en todas las tablas.
-- =====================================================================

begin;

-- Backfill de filas huérfanas de audit_log (evita que queden invisibles).
update public.audit_log
   set tenant_id = (select id from public.tenants where slug = 'world-guns')
 where tenant_id is null;

do $$
declare
  t text;
begin
  foreach t in array array[
    'productos', 'vendedores', 'administradores',
    'stock_movimientos', 'audit_log', 'ventas', 'app_config'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);

    -- Borrar policies abiertas heredadas (varios nombres históricos).
    execute format('drop policy if exists "%1$s_select" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_write"  on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_insert" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_update" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_tenant" on public.%1$s;', t);

    execute format(
      'create policy "%1$s_tenant" on public.%1$s
         for all
         using (tenant_id = public.current_tenant_id() or public.is_platform_admin())
         with check (tenant_id = public.current_tenant_id() or public.is_platform_admin());',
      t
    );
  end loop;
end $$;

-- Nombres cortos históricos que el loop no cubre.
drop policy if exists "audit_log_insert" on public.audit_log;
drop policy if exists "stock_mov_insert"  on public.stock_movimientos;
drop policy if exists "stock_mov_select"  on public.stock_movimientos;
drop policy if exists "ventas_insert"     on public.ventas;

commit;
