import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import '../utils/jwt.dart';
import '../utils/tenant_cache.dart';
import 'audit_service.dart';
import 'supabase_config_repository.dart';
import 'supabase_service.dart';

class ExchangeRateService extends ChangeNotifier {
  static const _rateKeyBase = 'exchange_rate_ars';
  static const _updatedAtKeyBase = 'exchange_rate_updated_at';
  static const _fromServerKeyBase = 'exchange_rate_from_server';
  static const defaultRate = 1500.0;

  double _rate = defaultRate;
  DateTime? _updatedAt;
  bool _hasServerRate = false;
  RealtimeChannel? _realtimeChannel;
  String? _tenantScope;

  final SupabaseConfigRepository _configRepo = SupabaseConfigRepository();

  double get rate => _rate;
  DateTime? get updatedAt => _updatedAt;

  /// True si el tipo de cambio viene del servidor (o modo local sin Supabase).
  /// Si es false con Supabase, no inventar precios ARS con el default 1500 (AR-11).
  bool get hasServerRate =>
      !SupabaseService.isConfigured || _hasServerRate;

  String get _rateKey => tenantCacheKey(_rateKeyBase, _tenantScope);
  String get _updatedAtKey => tenantCacheKey(_updatedAtKeyBase, _tenantScope);
  String get _fromServerKey =>
      tenantCacheKey(_fromServerKeyBase, _tenantScope);

  /// Aísla cache y Realtime por armería. Llamar antes de [load] al elegir tenant.
  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    if (_tenantScope == next) return;
    _tenantScope = next;
    _rate = defaultRate;
    _updatedAt = null;
    _hasServerRate = !SupabaseService.isConfigured;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

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
        detalle: 'ARS ${previous.toStringAsFixed(2)} → '
            '${newRate.toStringAsFixed(2)}',
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
        // AR-11: sin fila del tenant no inventamos precios ARS.
        // Conservamos el valor en memoria solo como placeholder del campo
        // de edición; hasServerRate pasa a false para ocultar ARS.
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
      // Error de red/RLS: NO bajar hasServerRate (evita “desaparecer” precios
      // si el sync falla pero la armería sí tiene dólar cargado).
      debugPrint('ExchangeRateService sync: $error');
    }
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;

    final tenantId = _tenantScope?.trim().isNotEmpty == true
        ? _tenantScope
        : _tenantIdFromJwt();
    _realtimeChannel?.unsubscribe();
    var channel = SupabaseService.client.channel(
      'app_config:${tenantId ?? 'all'}',
    );
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'app_config',
      filter: tenantId == null
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'tenant_id',
              value: tenantId,
            ),
      callback: (payload) {
        final record = payload.newRecord;
        if (record.isEmpty) return;

        final rate = (record['exchange_rate_ars'] as num?)?.toDouble();
        if (rate == null || rate <= 0) return;

        DateTime? updatedAt;
        final rawUpdatedAt = record['updated_at'] as String?;
        if (rawUpdatedAt != null) {
          updatedAt = DateTime.tryParse(rawUpdatedAt)?.toLocal();
        }

        _applyRate(
          rate,
          updatedAt: updatedAt,
          persist: true,
          fromServer: true,
        );
      },
    );
    _realtimeChannel = channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('ExchangeRateService realtime status=$status error=$error');
        unawaited(syncFromCloud(silent: true));
      }
    });
  }

  String? _tenantIdFromJwt() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
    final tenantId = (claim is String ? claim : claim?.toString())?.trim();
    return tenantId == null || tenantId.isEmpty ? null : tenantId;
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
