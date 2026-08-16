import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/pricing_limits.dart';
import '../models/product.dart';
import '../utils/municion_calibre.dart';
import '../utils/tenant_cache.dart';
import 'supabase_config_repository.dart';
import 'supabase_service.dart';

/// Recargos sobre precio lista y descuento en efectivo.
/// Con Supabase: por tenant en `app_config.pricing_settings`.
///
/// Override opcional por tipo (`municion`): p. ej. World Guns — 10% efectivo/
/// transferencia en toda la munición; 3 cuotas SI solo en munición de arma larga.
class PricingSettingsService extends ChangeNotifier {
  static const _efectivoKeyBase = 'pricing_efectivo_pct';
  static const _debitoKeyBase = 'pricing_debito_pct';
  static const _t1KeyBase = 'pricing_tarjeta1_pct';
  static const _t3KeyBase = 'pricing_tarjeta3_pct';
  static const _t6KeyBase = 'pricing_tarjeta6_pct';
  static const _t9KeyBase = 'pricing_tarjeta9_pct';
  static const _t12KeyBase = 'pricing_tarjeta12_pct';
  static const _t18KeyBase = 'pricing_tarjeta18_pct';
  static const _munEnabledKeyBase = 'pricing_municion_enabled';
  static const _munEfectivoKeyBase = 'pricing_municion_efectivo_pct';
  static const _munT3KeyBase = 'pricing_municion_tarjeta3_pct';
  static const _munTransferKeyBase = 'pricing_municion_transfer_efectivo';
  static const _munT3LargaKeyBase = 'pricing_municion_tarjeta3_solo_larga';
  static const _transferEfectivoKeyBase = 'pricing_transfer_efectivo';

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

  /// Si true, munición usa [municionDescuentoEfectivoPct] (y opcionalmente
  /// [municionRecargoTarjeta3Pct]); el resto de medios siguen el % global.
  bool municionOverrideEnabled = false;
  double municionDescuentoEfectivoPct = 10;
  double municionRecargoTarjeta3Pct = 0;

  /// Transferencia con el mismo monto que efectivo (promo munición).
  bool municionTransferenciaComoEfectivo = true;

  /// Si true, el recargo 3 cuotas de munición solo aplica a calibres de arma
  /// larga; munición de arma corta usa el % global de 3 cuotas.
  bool municionTarjeta3SoloArmaLarga = true;

  /// Tenant-wide (World Guns): transferencia = mismo descuento que efectivo
  /// en todo el catálogo.
  bool transferenciaComoEfectivo = false;

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
    bool? municionOverrideEnabled,
    double? municionEfectivoPct,
    double? municionTarjeta3Pct,
    bool? municionTransferenciaComoEfectivo,
    bool? municionTarjeta3SoloArmaLarga,
    bool? transferenciaComoEfectivo,
  }) async {
    descuentoEfectivoPct = PricingLimits.clamp('efectivo', efectivoPct);
    recargoDebitoPct = PricingLimits.clamp('debito', debitoPct);
    recargoTarjeta1Pct = PricingLimits.clamp('tarjeta1', tarjeta1Pct);
    recargoTarjeta3Pct = PricingLimits.clamp('tarjeta3', tarjeta3Pct);
    recargoTarjeta6Pct = PricingLimits.clamp('tarjeta6', tarjeta6Pct);
    recargoTarjeta9Pct = PricingLimits.clamp('tarjeta9', tarjeta9Pct);
    recargoTarjeta12Pct = PricingLimits.clamp('tarjeta12', tarjeta12Pct);
    recargoTarjeta18Pct = PricingLimits.clamp('tarjeta18', tarjeta18Pct);

    if (municionOverrideEnabled != null) {
      this.municionOverrideEnabled = municionOverrideEnabled;
    }
    if (municionEfectivoPct != null) {
      municionDescuentoEfectivoPct =
          PricingLimits.clamp('efectivo', municionEfectivoPct);
    }
    if (municionTarjeta3Pct != null) {
      municionRecargoTarjeta3Pct =
          PricingLimits.clamp('tarjeta3', municionTarjeta3Pct);
    }
    if (municionTransferenciaComoEfectivo != null) {
      this.municionTransferenciaComoEfectivo =
          municionTransferenciaComoEfectivo;
    }
    if (municionTarjeta3SoloArmaLarga != null) {
      this.municionTarjeta3SoloArmaLarga = municionTarjeta3SoloArmaLarga;
    }
    if (transferenciaComoEfectivo != null) {
      this.transferenciaComoEfectivo = transferenciaComoEfectivo;
    }

    await _persistCache();

    if (SupabaseService.isConfigured) {
      await _configRepo.upsertPricingSettings(toMap());
    }

    notifyListeners();
  }

  /// % efectivo según tipo de producto.
  double descuentoEfectivoPctFor(ProductType type) {
    if (type == ProductType.municion && municionOverrideEnabled) {
      return municionDescuentoEfectivoPct;
    }
    return descuentoEfectivoPct;
  }

  /// % recargo 3 cuotas según producto (calibre de munición puede limitar la promo).
  double recargoTarjeta3PctFor(Product product) {
    if (product.type != ProductType.municion || !municionOverrideEnabled) {
      return recargoTarjeta3Pct;
    }
    if (municionTarjeta3SoloArmaLarga &&
        !isMunicionArmaLarga(
          calibre: product.calibre,
          descripcion: product.descripcion,
        )) {
      return recargoTarjeta3Pct;
    }
    return municionRecargoTarjeta3Pct;
  }

  /// Transferencia = efectivo: flag tenant-wide o promo munición.
  bool transferenciaComoEfectivoFor(ProductType type) {
    if (transferenciaComoEfectivo) return true;
    return type == ProductType.municion &&
        municionOverrideEnabled &&
        municionTransferenciaComoEfectivo;
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'efectivo': descuentoEfectivoPct,
      'debito': recargoDebitoPct,
      'tarjeta1': recargoTarjeta1Pct,
      'tarjeta3': recargoTarjeta3Pct,
      'tarjeta6': recargoTarjeta6Pct,
      'tarjeta9': recargoTarjeta9Pct,
      'tarjeta12': recargoTarjeta12Pct,
      'tarjeta18': recargoTarjeta18Pct,
      'transferencia_como_efectivo': transferenciaComoEfectivo,
    };
    if (municionOverrideEnabled) {
      map['municion'] = <String, dynamic>{
        'efectivo': municionDescuentoEfectivoPct,
        'tarjeta3': municionRecargoTarjeta3Pct,
        'transferencia_como_efectivo': municionTransferenciaComoEfectivo,
        'tarjeta3_solo_arma_larga': municionTarjeta3SoloArmaLarga,
      };
    }
    return map;
  }

  /// Igual que [toMap] pero sin descuentos: efectivo/transferencia cotizan a
  /// lista. Mantiene los recargos de tarjeta y la promo de cuotas sin interés
  /// (que no es un descuento, sino un plan a precio de lista).
  ///
  /// Lo usa el registro de ventas para que el servidor (que recalcula precios
  /// desde este map) coincida con el cliente cuando la venta se cobra "sin
  /// descuento" (World Guns). Debe reflejar lo mismo que
  /// `PricingService.pricesFor(..., applyDiscounts: false)`.
  Map<String, dynamic> toMapWithoutDiscounts() {
    final map = toMap();
    map['efectivo'] = 0;
    map['transferencia_como_efectivo'] = false;
    // La promo munición se conserva, pero se apaga solo su parte de descuento
    // (efectivo/transferencia). El plan de 3 cuotas sin interés se mantiene.
    final mun = map['municion'];
    if (mun is Map) {
      final munWithoutDiscount = Map<String, dynamic>.from(mun);
      munWithoutDiscount['efectivo'] = 0;
      munWithoutDiscount['transferencia_como_efectivo'] = false;
      map['municion'] = munWithoutDiscount;
    }
    return map;
  }

  void _applyDefaults() {
    descuentoEfectivoPct = 5;
    recargoDebitoPct = 5;
    recargoTarjeta1Pct = 10;
    recargoTarjeta3Pct = 15;
    recargoTarjeta6Pct = 20;
    recargoTarjeta9Pct = 30;
    recargoTarjeta12Pct = 35;
    recargoTarjeta18Pct = 45;
    municionOverrideEnabled = false;
    municionDescuentoEfectivoPct = 10;
    municionRecargoTarjeta3Pct = 0;
    municionTransferenciaComoEfectivo = true;
    municionTarjeta3SoloArmaLarga = true;
    transferenciaComoEfectivo = false;
  }

  void _applyMap(Map<String, dynamic> map) {
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    bool? asBool(dynamic v) {
      if (v is bool) return v;
      if (v == 1 || v == '1' || v == 'true') return true;
      if (v == 0 || v == '0' || v == 'false') return false;
      return null;
    }

    void applyPct(String key, void Function(double) set) {
      final v = asDouble(map[key]);
      if (v != null) set(PricingLimits.clamp(key, v));
    }

    applyPct('efectivo', (v) => descuentoEfectivoPct = v);
    applyPct('debito', (v) => recargoDebitoPct = v);
    applyPct('tarjeta1', (v) => recargoTarjeta1Pct = v);
    applyPct('tarjeta3', (v) => recargoTarjeta3Pct = v);
    applyPct('tarjeta6', (v) => recargoTarjeta6Pct = v);
    applyPct('tarjeta9', (v) => recargoTarjeta9Pct = v);
    applyPct('tarjeta12', (v) => recargoTarjeta12Pct = v);
    applyPct('tarjeta18', (v) => recargoTarjeta18Pct = v);

    transferenciaComoEfectivo =
        asBool(map['transferencia_como_efectivo']) ?? false;

    final mun = map['municion'];
    if (mun is Map) {
      municionOverrideEnabled = true;
      final efectivo = asDouble(mun['efectivo']);
      if (efectivo != null) {
        municionDescuentoEfectivoPct =
            PricingLimits.clamp('efectivo', efectivo);
      }
      final t3 = asDouble(mun['tarjeta3']);
      if (t3 != null) {
        municionRecargoTarjeta3Pct = PricingLimits.clamp('tarjeta3', t3);
      }
      municionTransferenciaComoEfectivo =
          asBool(mun['transferencia_como_efectivo']) ?? true;
      municionTarjeta3SoloArmaLarga =
          asBool(mun['tarjeta3_solo_arma_larga']) ?? true;
    } else {
      municionOverrideEnabled = false;
    }
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
  String get _munEnabledKey =>
      tenantCacheKey(_munEnabledKeyBase, _tenantScope);
  String get _munEfectivoKey =>
      tenantCacheKey(_munEfectivoKeyBase, _tenantScope);
  String get _munT3Key => tenantCacheKey(_munT3KeyBase, _tenantScope);
  String get _munTransferKey =>
      tenantCacheKey(_munTransferKeyBase, _tenantScope);
  String get _munT3LargaKey =>
      tenantCacheKey(_munT3LargaKeyBase, _tenantScope);
  String get _transferEfectivoKey =>
      tenantCacheKey(_transferEfectivoKeyBase, _tenantScope);

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
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
    municionOverrideEnabled = prefs.getBool(_munEnabledKey) ?? false;
    municionDescuentoEfectivoPct =
        prefs.getDouble(_munEfectivoKey) ?? 10;
    municionRecargoTarjeta3Pct = prefs.getDouble(_munT3Key) ?? 0;
    municionTransferenciaComoEfectivo =
        prefs.getBool(_munTransferKey) ?? true;
    municionTarjeta3SoloArmaLarga =
        prefs.getBool(_munT3LargaKey) ?? true;
    transferenciaComoEfectivo =
        prefs.getBool(_transferEfectivoKey) ?? false;
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
    await prefs.setBool(_munEnabledKey, municionOverrideEnabled);
    await prefs.setDouble(_munEfectivoKey, municionDescuentoEfectivoPct);
    await prefs.setDouble(_munT3Key, municionRecargoTarjeta3Pct);
    await prefs.setBool(_munTransferKey, municionTransferenciaComoEfectivo);
    await prefs.setBool(_munT3LargaKey, municionTarjeta3SoloArmaLarga);
    await prefs.setBool(_transferEfectivoKey, transferenciaComoEfectivo);
  }
}
