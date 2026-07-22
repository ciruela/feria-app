import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recargos sobre precio lista y descuento en efectivo.
class PricingSettingsService extends ChangeNotifier {
  static const _efectivoKey = 'pricing_efectivo_pct';
  static const _debitoKey = 'pricing_debito_pct';
  static const _t1Key = 'pricing_tarjeta1_pct';
  static const _t3Key = 'pricing_tarjeta3_pct';
  static const _t6Key = 'pricing_tarjeta6_pct';
  static const _t9Key = 'pricing_tarjeta9_pct';
  static const _t12Key = 'pricing_tarjeta12_pct';
  static const _t18Key = 'pricing_tarjeta18_pct';

  double descuentoEfectivoPct = 5;
  double recargoDebitoPct = 5;
  double recargoTarjeta1Pct = 10;
  double recargoTarjeta3Pct = 15;
  double recargoTarjeta6Pct = 20;
  double recargoTarjeta9Pct = 30;
  double recargoTarjeta12Pct = 35;
  double recargoTarjeta18Pct = 45;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    descuentoEfectivoPct = prefs.getDouble(_efectivoKey) ?? 5;
    recargoDebitoPct = prefs.getDouble(_debitoKey) ?? 5;
    recargoTarjeta1Pct = prefs.getDouble(_t1Key) ?? 10;
    recargoTarjeta3Pct = prefs.getDouble(_t3Key) ?? 15;
    recargoTarjeta6Pct = prefs.getDouble(_t6Key) ?? 20;
    recargoTarjeta9Pct = prefs.getDouble(_t9Key) ?? 30;
    recargoTarjeta12Pct = prefs.getDouble(_t12Key) ?? 35;
    recargoTarjeta18Pct = prefs.getDouble(_t18Key) ?? 45;
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
    final prefs = await SharedPreferences.getInstance();
    descuentoEfectivoPct = efectivoPct;
    recargoDebitoPct = debitoPct;
    recargoTarjeta1Pct = tarjeta1Pct;
    recargoTarjeta3Pct = tarjeta3Pct;
    recargoTarjeta6Pct = tarjeta6Pct;
    recargoTarjeta9Pct = tarjeta9Pct;
    recargoTarjeta12Pct = tarjeta12Pct;
    recargoTarjeta18Pct = tarjeta18Pct;

    await prefs.setDouble(_efectivoKey, efectivoPct);
    await prefs.setDouble(_debitoKey, debitoPct);
    await prefs.setDouble(_t1Key, tarjeta1Pct);
    await prefs.setDouble(_t3Key, tarjeta3Pct);
    await prefs.setDouble(_t6Key, tarjeta6Pct);
    await prefs.setDouble(_t9Key, tarjeta9Pct);
    await prefs.setDouble(_t12Key, tarjeta12Pct);
    await prefs.setDouble(_t18Key, tarjeta18Pct);
    notifyListeners();
  }
}
