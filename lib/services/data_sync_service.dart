import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/app_config.dart';
import 'catalog_service.dart';
import 'exchange_rate_service.dart';
import 'seller_service.dart';
import 'supabase_service.dart';

/// Reconciliación de catálogo / vendedores / FX.
///
/// AR-18: el push va por Realtime; este servicio solo hace:
/// - sync bajo demanda
/// - reconciliación al volver a foreground
/// - backup lento (no el poll de 5s que duplicaba Realtime)
class DataSyncService with WidgetsBindingObserver {
  DataSyncService({
    required CatalogService catalog,
    required SellerService sellers,
    required ExchangeRateService exchangeRate,
  })  : _catalog = catalog,
        _sellers = sellers,
        _exchangeRate = exchangeRate;

  /// Backup si Realtime se cae; no reemplaza el canal push.
  static const backupInterval = Duration(minutes: 5);

  final CatalogService _catalog;
  final SellerService _sellers;
  final ExchangeRateService _exchangeRate;

  Timer? _backupTimer;
  bool _syncing = false;
  bool _started = false;

  bool get isEnabled =>
      AppConfig.usesRemoteCatalog ||
      AppConfig.usesRemoteSellers ||
      SupabaseService.isConfigured;

  void start() {
    if (!isEnabled || _started) return;
    _started = true;

    WidgetsBinding.instance.addObserver(this);
    _backupTimer?.cancel();
    _backupTimer = Timer.periodic(backupInterval, (_) {
      unawaited(syncAll(silent: true));
    });
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncAll(silent: true));
    }
  }

  Future<void> syncAll({bool silent = false}) async {
    if (_syncing) return;
    if (AppConfig.useSupabase &&
        (!_catalog.hasTenantScope || !_sellers.hasTenantScope)) {
      return;
    }

    _syncing = true;
    try {
      final tasks = <Future<void>>[];
      if (AppConfig.usesRemoteCatalog) {
        tasks.add(_catalog.syncFromCloud(silent: silent));
      }
      if (AppConfig.usesRemoteSellers) {
        tasks.add(_sellers.syncFromCloud(silent: silent));
      }
      if (SupabaseService.isConfigured) {
        // Solo lectura (AR-11/AR-18): nunca upsert desde el sync.
        tasks.add(_exchangeRate.syncFromCloud(silent: silent));
      }
      await Future.wait(tasks);
    } finally {
      _syncing = false;
    }
  }

  void dispose() => stop();
}
