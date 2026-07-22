import 'dart:async';

import '../config/app_config.dart';
import 'catalog_service.dart';
import 'exchange_rate_service.dart';
import 'seller_service.dart';
import 'supabase_service.dart';

/// Sincroniza catálogo, vendedores y tipo de cambio en segundo plano.
class DataSyncService {
  DataSyncService({
    required CatalogService catalog,
    required SellerService sellers,
    required ExchangeRateService exchangeRate,
  })  : _catalog = catalog,
        _sellers = sellers,
        _exchangeRate = exchangeRate;

  static const syncInterval = Duration(seconds: 5);

  final CatalogService _catalog;
  final SellerService _sellers;
  final ExchangeRateService _exchangeRate;

  Timer? _timer;
  bool _syncing = false;

  bool get isEnabled =>
      AppConfig.usesRemoteCatalog ||
      AppConfig.usesRemoteSellers ||
      SupabaseService.isConfigured;

  void start() {
    if (!isEnabled) return;

    stop();
    _timer = Timer.periodic(syncInterval, (_) {
      unawaited(syncAll(silent: true));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncAll({bool silent = false}) async {
    if (_syncing) return;

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
        tasks.add(_exchangeRate.syncFromCloud(silent: silent));
      }
      await Future.wait(tasks);
    } finally {
      _syncing = false;
    }
  }

  void dispose() => stop();
}
