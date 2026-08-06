-- =====================================================================
-- 039_ops_hardening.sql
-- ---------------------------------------------------------------------
-- AR-25 (parte SQL): índice de trazabilidad por producto.
--   La consulta más propia del rubro (historial de un arma / lote de
--   munición) hoy recorre todo el historial del tenant porque ningún
--   índice incluye producto_id. Se agrega (tenant_id, producto_id, fecha).
--   Realtime de vendedores/administradores ya se arregló en 035.
--   Retención de audit_log/ventas: queda como job de servicio (documentado
--   en AR-25); audit_log es inmutable para el cliente (AR-7).
-- =====================================================================

begin;

create index if not exists stock_movimientos_tenant_producto_fecha_idx
  on public.stock_movimientos (tenant_id, producto_id, created_at desc);

commit;
