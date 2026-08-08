import '../utils/jwt.dart';
import 'supabase_service.dart';

class SupabaseConfigRepository {
  static const _table = 'app_config';
  static const _globalId = 'global';

  Future<({double rate, DateTime updatedAt})?> fetchExchangeRate() async {
    var query = SupabaseService.client
        .from(_table)
        .select('exchange_rate_ars, updated_at')
        .eq('id', _globalId);

    // Filtro explícito por tenant (además de RLS) para no cruzar armerías.
    final tenantId = _tenantIdFromJwt();
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }

    final row = await query.maybeSingle();
    if (row == null) return null;

    final rate = (row['exchange_rate_ars'] as num?)?.toDouble();
    if (rate == null || rate <= 0) return null;

    return (
      rate: rate,
      updatedAt: DateTime.parse(row['updated_at'] as String).toLocal(),
    );
  }

  Future<void> upsertExchangeRate(double rate) async {
    final tenantId = _tenantIdFromJwt();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'No hay armería activa en la sesión. '
        'Elegí una organización antes de guardar el tipo de cambio.',
      );
    }

    final payload = <String, dynamic>{
      'id': _globalId,
      'exchange_rate_ars': rate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'tenant_id': tenantId,
    };

    // PK compuesta (tenant_id, id) — AR-11.
    await SupabaseService.client.from(_table).upsert(
          payload,
          onConflict: 'tenant_id,id',
        );
  }

  Future<Map<String, dynamic>?> fetchPricingSettings() async {
    var query = SupabaseService.client
        .from(_table)
        .select('pricing_settings')
        .eq('id', _globalId);

    final tenantId = _tenantIdFromJwt();
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }

    final row = await query.maybeSingle();
    if (row == null) return null;
    final raw = row['pricing_settings'];
    if (raw is! Map) return null;

    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is num) {
        out[key] = value.toDouble();
      } else if (value is Map) {
        out[key] = Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else if (value is bool) {
        out[key] = value;
      }
    }
    return out.isEmpty ? null : out;
  }

  Future<void> upsertPricingSettings(Map<String, dynamic> settings) async {
    final tenantId = _tenantIdFromJwt();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'No hay armería activa en la sesión. '
        'Elegí una organización antes de guardar las promos.',
      );
    }

    // Solo UPDATE: no pisar exchange_rate_ars. Requiere fila app_config del tenant.
    final updated = await SupabaseService.client
        .from(_table)
        .update({
          'pricing_settings': settings,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _globalId)
        .eq('tenant_id', tenantId)
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError(
        'No hay configuración de la armería. '
        'Guardá el tipo de cambio primero y reintentá las promos.',
      );
    }
  }

  Future<String?> fetchAdminMasterPinHash() async {
    var query = SupabaseService.client
        .from(_table)
        .select('admin_master_pin_hash')
        .eq('id', _globalId);

    final tenantId = _tenantIdFromJwt();
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }

    final row = await query.maybeSingle();
    if (row == null) return null;
    final hash = (row['admin_master_pin_hash'] as String?)?.trim();
    if (hash == null || hash.isEmpty) return null;
    return hash;
  }

  Future<void> upsertAdminMasterPinHash(String pinHash) async {
    final tenantId = _tenantIdFromJwt();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'No hay armería activa en la sesión. '
        'Elegí una organización antes de cambiar el PIN.',
      );
    }

    final updated = await SupabaseService.client
        .from(_table)
        .update({
          'admin_master_pin_hash': pinHash,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', _globalId)
        .eq('tenant_id', tenantId)
        .select('id');

    if ((updated as List).isEmpty) {
      throw StateError(
        'No hay configuración de la armería. '
        'Guardá el tipo de cambio primero y reintentá el PIN.',
      );
    }
  }

  String? _tenantIdFromJwt() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
    final tenantId = (claim is String ? claim : claim?.toString())?.trim();
    return tenantId == null || tenantId.isEmpty ? null : tenantId;
  }
}
