import '../utils/jwt.dart';
import 'supabase_service.dart';

class SupabaseConfigRepository {
  static const _table = 'app_config';
  static const _globalId = 'global';

  Future<({double rate, DateTime updatedAt})?> fetchExchangeRate() async {
    final row = await SupabaseService.client
        .from(_table)
        .select('exchange_rate_ars, updated_at')
        .eq('id', _globalId)
        .maybeSingle();

    if (row == null) return null;

    return (
      rate: (row['exchange_rate_ars'] as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Future<void> upsertExchangeRate(double rate) async {
    final tenantId = _tenantIdFromJwt();
    final payload = <String, dynamic>{
      'id': _globalId,
      'exchange_rate_ars': rate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (tenantId != null) 'tenant_id': tenantId,
    };

    // PK compuesta (tenant_id, id) — AR-11.
    await SupabaseService.client.from(_table).upsert(
          payload,
          onConflict: tenantId != null ? 'tenant_id,id' : 'id',
        );
  }

  String? _tenantIdFromJwt() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
    final tenantId = (claim is String ? claim : claim?.toString())?.trim();
    return tenantId == null || tenantId.isEmpty ? null : tenantId;
  }
}
