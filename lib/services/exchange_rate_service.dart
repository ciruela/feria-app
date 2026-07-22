import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config_repository.dart';
import 'supabase_service.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _rateKey = 'exchange_rate_ars';
  static const _updatedAtKey = 'exchange_rate_updated_at';
  static const defaultRate = 1500.0;

  double _rate = defaultRate;
  DateTime? _updatedAt;
  RealtimeChannel? _realtimeChannel;

  final SupabaseConfigRepository _configRepo = SupabaseConfigRepository();

  double get rate => _rate;
  DateTime? get updatedAt => _updatedAt;

  Future<void> load() async {
    await _loadFromCache();

    if (SupabaseService.isConfigured) {
      await _syncFromSupabase();
      _subscribeRealtime();
    }

    notifyListeners();
  }

  Future<void> saveRate(double newRate) async {
    if (newRate <= 0) return;

    _rate = newRate;
    _updatedAt = DateTime.now();
    await _persistCache();

    if (SupabaseService.isConfigured) {
      await _configRepo.upsertExchangeRate(newRate);
    }

    notifyListeners();
  }

  Future<void> syncFromCloud({bool silent = false}) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await _syncFromSupabase();
    } catch (error) {
      if (silent) {
        debugPrint('ExchangeRateService silent sync: $error');
      } else {
        debugPrint('ExchangeRateService sync: $error');
      }
    }
  }

  Future<void> _syncFromSupabase() async {
    try {
      final remote = await _configRepo.fetchExchangeRate();
      if (remote == null) {
        await _configRepo.upsertExchangeRate(_rate);
        return;
      }

      _applyRate(remote.rate, updatedAt: remote.updatedAt, persist: true);
    } catch (error) {
      debugPrint('ExchangeRateService sync: $error');
    }
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('public:app_config')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_config',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;

            final rate = (record['exchange_rate_ars'] as num?)?.toDouble();
            if (rate == null || rate <= 0) return;

            DateTime? updatedAt;
            final rawUpdatedAt = record['updated_at'] as String?;
            if (rawUpdatedAt != null) {
              updatedAt = DateTime.tryParse(rawUpdatedAt);
            }

            _applyRate(rate, updatedAt: updatedAt, persist: true);
          },
        )
        .subscribe();
  }

  void _applyRate(
    double rate, {
    DateTime? updatedAt,
    bool persist = false,
  }) {
    if (rate <= 0) return;

    final changed = (_rate - rate).abs() > 0.0001 ||
        updatedAt != _updatedAt;

    _rate = rate;
    _updatedAt = updatedAt ?? DateTime.now();

    if (persist) {
      _persistCache();
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _rate = prefs.getDouble(_rateKey) ?? defaultRate;
    final timestamp = prefs.getInt(_updatedAtKey);
    _updatedAt = timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, _rate);
    if (_updatedAt != null) {
      await prefs.setInt(_updatedAtKey, _updatedAt!.millisecondsSinceEpoch);
    }
  }

  double toArs(double usd) => usd * _rate;

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
