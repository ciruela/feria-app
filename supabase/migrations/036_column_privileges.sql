-- =====================================================================
-- 036_column_privileges.sql
-- ---------------------------------------------------------------------
-- AR-26: un REVOKE por columna NO resta de un GRANT de tabla. Los
--        `revoke update (stock)` / `revoke select (codigo_vendedores)`
--        corrieron sin efecto porque existía el GRANT de tabla.
--        Fix correcto: revocar el permiso de tabla y re-otorgar por
--        columna (enumerando las permitidas).
-- AR-23 (parcial): mass assignment — `stock` y `updated_at` no deben ser
--        escribibles por el cliente (stock va por RPC; updated_at por trigger).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- productos.activo: borrado lógico (AR-23) para preservar trazabilidad
-- sin romper la FK con on delete restrict.
-- ---------------------------------------------------------------------
alter table public.productos
  add column if not exists activo boolean not null default true;

-- ---------------------------------------------------------------------
-- productos: updated_at siempre lo pone la base (evita antedatar).
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_updated_at_trg on public.productos;
create trigger set_updated_at_trg
  before insert or update on public.productos
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- productos: quitar los grants de tabla y re-otorgar por columna.
--   Excluidas de escritura: stock (solo RPC SECURITY DEFINER) y
--   updated_at (trigger). anon pierde toda escritura.
-- ---------------------------------------------------------------------
revoke insert, update on public.productos from anon, authenticated;

grant insert (
  id, type, marca, calibre, codigo, modelo, descripcion,
  precio_usd, foto, foto_url, fotos, stock_inicial, rounds_per_box,
  tenant_id, activo
) on public.productos to authenticated;

grant update (
  type, marca, calibre, codigo, modelo, descripcion,
  precio_usd, foto, foto_url, fotos, stock_inicial, rounds_per_box,
  activo
) on public.productos to authenticated;

-- ---------------------------------------------------------------------
-- tenants: codigo_vendedores no debe ser legible por el cliente.
--   Se revoca el SELECT de tabla y se re-otorga por columna.
-- ---------------------------------------------------------------------
revoke select on public.tenants from anon, authenticated;

grant select (
  id, nombre, slug, activo, plan, created_at, storefront_enabled
) on public.tenants to authenticated;

-- anon solo necesita lo público (resolución por slug); nunca codigo_vendedores.
grant select (
  id, nombre, slug, activo, storefront_enabled
) on public.tenants to anon;

commit;
