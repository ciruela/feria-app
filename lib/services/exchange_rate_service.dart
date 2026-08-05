import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import 'audit_service.dart';
import 'supabase_config_repository.dart';
import 'supabase_service.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _rateKey = 'exchange_rate_ars';
  static const _updatedAtKey = 'exchange_rate_updated_at';
  static const _fromServerKey = 'exchange_rate_from_server';
  static const defaultRate = 1500.0;

  double _rate = defaultRate;
  DateTime? _updatedAt;
  bool _hasServerRate = false;
  RealtimeChannel? _realtimeChannel;

  final SupabaseConfigRepository _configRepo = SupabaseConfigRepository();

  double get rate => _rate;
  DateTime? get updatedAt => _updatedAt;

  /// True si el tipo de cambio viene del servidor (o modo local sin Supabase).
  /// Si es false con Supabase, no inventar precios ARS con el default 1500 (AR-11).
  bool get hasServerRate =>
      !SupabaseService.isConfigured || _hasServerRate;

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

    final previous = _rate;
    _rate = newRate;
    _updatedAt = DateTime.now();
    _hasServerRate = !SupabaseService.isConfigured;
    await _persistCache();

    if (SupabaseService.isConfigured) {
      await _configRepo.upsertExchangeRate(newRate);
      _hasServerRate = true;
      await _persistCache();
    }

    if ((previous - newRate).abs() > 0.0001) {
      AuditService.instance.log(
        accion: 'Actualizó tipo de cambio',
        entidad: AuditEntidad.tipoCambio,
        detalle: 'ARS ${previous.toStringAsFixed(0)} → '
            '${newRate.toStringAsFixed(0)}',
      );
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
        // AR-11: lista vacía / sin fila del tenant ≠ "crear".
        // No hacer upsert desde el sync (evita el bucle cada 5s).
        if (_hasServerRate) {
          _hasServerRate = false;
          await _persistCache();
          notifyListeners();
        }
        return;
      }

      _applyRate(
        remote.rate,
        updatedAt: remote.updatedAt,
        persist: true,
        fromServer: true,
      );
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

            _applyRate(
              rate,
              updatedAt: updatedAt,
              persist: true,
              fromServer: true,
            );
          },
        )
        .subscribe();
  }

  void _applyRate(
    double rate, {
    DateTime? updatedAt,
    bool persist = false,
    bool fromServer = false,
  }) {
    if (rate <= 0) return;

    final changed = (_rate - rate).abs() > 0.0001 ||
        updatedAt != _updatedAt ||
        (fromServer && !_hasServerRate);

    _rate = rate;
    _updatedAt = updatedAt ?? DateTime.now();
    if (fromServer) {
      _hasServerRate = true;
    }

    if (persist) {
      _persistCache();
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _hasServerRate = prefs.getBool(_fromServerKey) ?? false;
    _rate = prefs.getDouble(_rateKey) ?? defaultRate;
    final timestamp = prefs.getInt(_updatedAtKey);
    _updatedAt = timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, _rate);
    await prefs.setBool(_fromServerKey, _hasServerRate);
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
