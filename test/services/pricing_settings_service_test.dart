import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('save clamps out-of-range percentages', () async {
    final settings = PricingSettingsService();

    await settings.save(
      efectivoPct: 50,
      debitoPct: -5,
      tarjeta1Pct: 10,
      tarjeta3Pct: 15,
      tarjeta6Pct: 20,
      tarjeta9Pct: 30,
      tarjeta12Pct: 35,
      tarjeta18Pct: 120,
    );

    expect(settings.descuentoEfectivoPct, 30);
    expect(settings.recargoDebitoPct, 0);
    expect(settings.recargoTarjeta1Pct, 10);
    expect(settings.recargoTarjeta18Pct, 100);
  });

  test('save keeps in-range values unchanged', () async {
    final settings = PricingSettingsService();

    await settings.save(
      efectivoPct: 5,
      debitoPct: 5,
      tarjeta1Pct: 10,
      tarjeta3Pct: 15,
      tarjeta6Pct: 20,
      tarjeta9Pct: 30,
      tarjeta12Pct: 35,
      tarjeta18Pct: 45,
    );

    expect(settings.descuentoEfectivoPct, 5);
    expect(settings.recargoDebitoPct, 5);
    expect(settings.recargoTarjeta1Pct, 10);
    expect(settings.recargoTarjeta3Pct, 15);
    expect(settings.recargoTarjeta6Pct, 20);
    expect(settings.recargoTarjeta9Pct, 30);
    expect(settings.recargoTarjeta12Pct, 35);
    expect(settings.recargoTarjeta18Pct, 45);
  });
}
