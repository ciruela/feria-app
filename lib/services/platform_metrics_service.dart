import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_metrics.dart';
import 'supabase_service.dart';

/// Carga métricas cross-tenant para el panel super admin.
///
/// 1. Intenta la Edge Function `platform-metrics` (service role en servidor).
/// 2. Si no está deployada o falla, agrega vía RLS de platform admin.
class PlatformMetricsService {
  Future<PlatformMetrics> load() async {
    final fromFunction = await _tryEdgeFunction();
    if (fromFunction != null) return fromFunction;
    return _loadViaRls();
  }

  Future<PlatformMetrics?> _tryEdgeFunction() async {
    try {
      final res = await SupabaseService.client.functions.invoke(
        'platform-metrics',
      );
      final data = res.data;
      if (data is! Map) return null;

      final map = data.cast<String, dynamic>();
      if (map.containsKey('error')) return null;
      if (res.status >= 400) return null;

      return PlatformMetrics.fromJson(map);
    } on FunctionException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PlatformMetrics> _loadViaRls() async {
    final client = SupabaseService.client;

    final tenantsRes = await client
        .from('tenants')
        .select('id,nombre,slug,activo');
    // AR-14: ventas sin SELECT PostgREST; agregados vía RPC (sin PII).
    final ventasRes = await client.rpc('list_ventas_platform_metrics');
    final vendedoresRes = await client
        .from('vendedores')
        .select('tenant_id,activo');

    return aggregatePlatformMetrics(
      tenants: (tenantsRes as List)
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(),
      ventas: (ventasRes as List)
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(),
      vendedores: (vendedoresRes as List)
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(),
    );
  }
}
