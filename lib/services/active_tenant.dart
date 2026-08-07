import '../utils/jwt.dart';
import 'supabase_service.dart';

/// Tenant activo según el JWT de Supabase (equivale a `current_tenant_id()` del
/// RLS). Devuelve null en vista plataforma o sin sesión.
///
/// Se usa para filtrar en el CLIENTE **toda** lectura por tenant y no depender
/// solo del RLS: un `platform_admin` pasa el RLS de todas las armerías, así que
/// sin este filtro una lectura cargaría datos cruzados de otros tenants
/// (fuente del incidente de mezcla entre tenants al importar).
String? activeTenantIdFromJwt() {
  final session = SupabaseService.client.auth.currentSession;
  if (session == null) return null;
  final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
  final tenantId = (claim is String ? claim : claim?.toString())?.trim();
  return tenantId == null || tenantId.isEmpty ? null : tenantId;
}
