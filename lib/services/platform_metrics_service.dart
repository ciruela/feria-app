import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/platform_metrics.dart';
import '../utils/app_logger.dart';
import '../utils/retry.dart';
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
      final res = await withTimeoutRetry(
        () => SupabaseService.client.functions.invoke('platform-metrics'),
        timeout: const Duration(seconds: 20),
        maxAttempts: 2,
        operation: 'platform-metrics',
      );
      final data = res.data;
      if (data is! Map) {
        AppLogger.warn('platform-metrics respondió sin mapa');
        return null;
      }

      final map = data.cast<String, dynamic>();
      if (map.containsKey('error')) {
        AppLogger.warn(
          'platform-metrics error: ${map['error']}',
        );
        return null;
      }
      if (res.status >= 400) {
        AppLogger.warn('platform-metrics HTTP ${res.status}');
        return null;
      }

      return PlatformMetrics.fromJson(map);
    } on FunctionException catch (error, stackTrace) {
      AppLogger.warn(
        'platform-metrics FunctionException (¿sin deploy?)',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'platform-metrics falló; uso fallback RLS',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<PlatformMetrics> _loadViaRls() async {
    final client = SupabaseService.client;

    final tenantsRes = await withTimeoutRetry(
      () => client.from('tenants').select('id,nombre,slug,activo'),
      operation: 'platform tenants',
    );
    // AR-14: ventas sin SELECT PostgREST; agregados vía RPC (sin PII).
    final ventasRes = await withTimeoutRetry(
      () => client.rpc('list_ventas_platform_metrics'),
      operation: 'list_ventas_platform_metrics',
    );
    final vendedoresRes = await withTimeoutRetry(
      () => client.from('vendedores').select('tenant_id,activo'),
      operation: 'platform vendedores',
    );

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
