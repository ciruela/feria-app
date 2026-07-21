import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PricingSettingsService extends ChangeNotifier {
  static const _efectivoKey = 'pricing_efectivo_pct';
  static const _t3Key = 'pricing_tarjeta3_pct';
  static const _t6Key = 'pricing_tarjeta6_pct';
  static const _t12Key = 'pricing_tarjeta12_pct';

  double descuentoEfectivoPct = 5;
  double recargoTarjeta3Pct = 10;
  double recargoTarjeta6Pct = 20;
  double recargoTarjeta12Pct = 35;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    descuentoEfectivoPct = prefs.getDouble(_efectivoKey) ?? 5;
    recargoTarjeta3Pct = prefs.getDouble(_t3Key) ?? 10;
    recargoTarjeta6Pct = prefs.getDouble(_t6Key) ?? 20;
    recargoTarjeta12Pct = prefs.getDouble(_t12Key) ?? 35;
    notifyListeners();
  }

  Future<void> save({
    required double efectivoPct,
    required double tarjeta3Pct,
    required double tarjeta6Pct,
    required double tarjeta12Pct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    descuentoEfectivoPct = efectivoPct;
    recargoTarjeta3Pct = tarjeta3Pct;
    recargoTarjeta6Pct = tarjeta6Pct;
    recargoTarjeta12Pct = tarjeta12Pct;

    await prefs.setDouble(_efectivoKey, efectivoPct);
    await prefs.setDouble(_t3Key, tarjeta3Pct);
    await prefs.setDouble(_t6Key, tarjeta6Pct);
    await prefs.setDouble(_t12Key, tarjeta12Pct);
    notifyListeners();
  }
}
