import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/tenant_cache.dart';
import 'supabase_config_repository.dart';
import 'supabase_service.dart';

/// Recargos sobre precio lista y descuento en efectivo.
/// Con Supabase: por tenant en `app_config.pricing_settings`.
class PricingSettingsService extends ChangeNotifier {
  static const _efectivoKeyBase = 'pricing_efectivo_pct';
  static const _debitoKeyBase = 'pricing_debito_pct';
  static const _t1KeyBase = 'pricing_tarjeta1_pct';
  static const _t3KeyBase = 'pricing_tarjeta3_pct';
  static const _t6KeyBase = 'pricing_tarjeta6_pct';
  static const _t9KeyBase = 'pricing_tarjeta9_pct';
  static const _t12KeyBase = 'pricing_tarjeta12_pct';
  static const _t18KeyBase = 'pricing_tarjeta18_pct';

  final SupabaseConfigRepository _configRepo = SupabaseConfigRepository();
  String? _tenantScope;

  double descuentoEfectivoPct = 5;
  double recargoDebitoPct = 5;
  double recargoTarjeta1Pct = 10;
  double recargoTarjeta3Pct = 15;
  double recargoTarjeta6Pct = 20;
  double recargoTarjeta9Pct = 30;
  double recargoTarjeta12Pct = 35;
  double recargoTarjeta18Pct = 45;

  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    if (_tenantScope == next) return;
    _tenantScope = next;
    _applyDefaults();
  }

  Future<void> load() async {
    await _loadFromCache();
    if (SupabaseService.isConfigured) {
      try {
        final remote = await _configRepo.fetchPricingSettings();
        if (remote != null) {
          _applyMap(remote);
          await _persistCache();
        }
      } catch (error) {
        debugPrint('PricingSettingsService sync: $error');
      }
    }
    notifyListeners();
  }

  Future<void> save({
    required double efectivoPct,
    required double debitoPct,
    required double tarjeta1Pct,
    required double tarjeta3Pct,
    required double tarjeta6Pct,
    required double tarjeta9Pct,
    required double tarjeta12Pct,
    required double tarjeta18Pct,
  }) async {
    descuentoEfectivoPct = efectivoPct;
    recargoDebitoPct = debitoPct;
    recargoTarjeta1Pct = tarjeta1Pct;
    recargoTarjeta3Pct = tarjeta3Pct;
    recargoTarjeta6Pct = tarjeta6Pct;
    recargoTarjeta9Pct = tarjeta9Pct;
    recargoTarjeta12Pct = tarjeta12Pct;
    recargoTarjeta18Pct = tarjeta18Pct;

    await _persistCache();

    if (SupabaseService.isConfigured) {
      await _configRepo.upsertPricingSettings(toMap());
    }

    notifyListeners();
  }

  Map<String, double> toMap() => {
        'efectivo': descuentoEfectivoPct,
        'debito': recargoDebitoPct,
        'tarjeta1': recargoTarjeta1Pct,
        'tarjeta3': recargoTarjeta3Pct,
        'tarjeta6': recargoTarjeta6Pct,
        'tarjeta9': recargoTarjeta9Pct,
        'tarjeta12': recargoTarjeta12Pct,
        'tarjeta18': recargoTarjeta18Pct,
      };

  void _applyDefaults() {
    descuentoEfectivoPct = 5;
    recargoDebitoPct = 5;
    recargoTarjeta1Pct = 10;
    recargoTarjeta3Pct = 15;
    recargoTarjeta6Pct = 20;
    recargoTarjeta9Pct = 30;
    recargoTarjeta12Pct = 35;
    recargoTarjeta18Pct = 45;
  }

  void _applyMap(Map<String, double> map) {
    descuentoEfectivoPct = map['efectivo'] ?? descuentoEfectivoPct;
    recargoDebitoPct = map['debito'] ?? recargoDebitoPct;
    recargoTarjeta1Pct = map['tarjeta1'] ?? recargoTarjeta1Pct;
    recargoTarjeta3Pct = map['tarjeta3'] ?? recargoTarjeta3Pct;
    recargoTarjeta6Pct = map['tarjeta6'] ?? recargoTarjeta6Pct;
    recargoTarjeta9Pct = map['tarjeta9'] ?? recargoTarjeta9Pct;
    recargoTarjeta12Pct = map['tarjeta12'] ?? recargoTarjeta12Pct;
    recargoTarjeta18Pct = map['tarjeta18'] ?? recargoTarjeta18Pct;
  }

  String get _efectivoKey =>
      tenantCacheKey(_efectivoKeyBase, _tenantScope);
  String get _debitoKey => tenantCacheKey(_debitoKeyBase, _tenantScope);
  String get _t1Key => tenantCacheKey(_t1KeyBase, _tenantScope);
  String get _t3Key => tenantCacheKey(_t3KeyBase, _tenantScope);
  String get _t6Key => tenantCacheKey(_t6KeyBase, _tenantScope);
  String get _t9Key => tenantCacheKey(_t9KeyBase, _tenantScope);
  String get _t12Key => tenantCacheKey(_t12KeyBase, _tenantScope);
  String get _t18Key => tenantCacheKey(_t18KeyBase, _tenantScope);

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Preferir claves por tenant; fallback a claves legacy sin tenant.
    descuentoEfectivoPct =
        prefs.getDouble(_efectivoKey) ?? prefs.getDouble(_efectivoKeyBase) ?? 5;
    recargoDebitoPct =
        prefs.getDouble(_debitoKey) ?? prefs.getDouble(_debitoKeyBase) ?? 5;
    recargoTarjeta1Pct =
        prefs.getDouble(_t1Key) ?? prefs.getDouble(_t1KeyBase) ?? 10;
    recargoTarjeta3Pct =
        prefs.getDouble(_t3Key) ?? prefs.getDouble(_t3KeyBase) ?? 15;
    recargoTarjeta6Pct =
        prefs.getDouble(_t6Key) ?? prefs.getDouble(_t6KeyBase) ?? 20;
    recargoTarjeta9Pct =
        prefs.getDouble(_t9Key) ?? prefs.getDouble(_t9KeyBase) ?? 30;
    recargoTarjeta12Pct =
        prefs.getDouble(_t12Key) ?? prefs.getDouble(_t12KeyBase) ?? 35;
    recargoTarjeta18Pct =
        prefs.getDouble(_t18Key) ?? prefs.getDouble(_t18KeyBase) ?? 45;
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_efectivoKey, descuentoEfectivoPct);
    await prefs.setDouble(_debitoKey, recargoDebitoPct);
    await prefs.setDouble(_t1Key, recargoTarjeta1Pct);
    await prefs.setDouble(_t3Key, recargoTarjeta3Pct);
    await prefs.setDouble(_t6Key, recargoTarjeta6Pct);
    await prefs.setDouble(_t9Key, recargoTarjeta9Pct);
    await prefs.setDouble(_t12Key, recargoTarjeta12Pct);
    await prefs.setDouble(_t18Key, recargoTarjeta18Pct);
  }
}
