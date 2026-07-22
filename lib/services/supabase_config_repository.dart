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
    await SupabaseService.client.from(_table).upsert({
      'id': _globalId,
      'exchange_rate_ars': rate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
