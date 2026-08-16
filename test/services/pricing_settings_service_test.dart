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

  test('toMap incluye override munición cuando está activo', () async {
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
      municionOverrideEnabled: true,
      municionEfectivoPct: 10,
      municionTarjeta3Pct: 0,
      municionTransferenciaComoEfectivo: true,
      municionTarjeta3SoloArmaLarga: true,
    );

    final map = settings.toMap();
    expect(map['efectivo'], 5);
    expect(map['transferencia_como_efectivo'], isFalse);
    expect(map['municion'], isA<Map>());
    final mun = map['municion'] as Map;
    expect(mun['efectivo'], 10);
    expect(mun['tarjeta3'], 0);
    expect(mun['transferencia_como_efectivo'], isTrue);
    expect(mun['tarjeta3_solo_arma_larga'], isTrue);
  });

  test('toMapWithoutDiscounts: efectivo 0, promo cuotas sin interés se mantiene', () async {
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
      municionOverrideEnabled: true,
      municionEfectivoPct: 10,
      municionTarjeta3Pct: 0,
      municionTransferenciaComoEfectivo: true,
      municionTarjeta3SoloArmaLarga: true,
      transferenciaComoEfectivo: true,
    );

    final map = settings.toMapWithoutDiscounts();
    // Descuentos apagados: efectivo a 0 y transferencia a lista.
    expect(map['efectivo'], 0);
    expect(map['transferencia_como_efectivo'], isFalse);
    // La promo munición se conserva, pero sin su parte de descuento: la promo
    // de 3 cuotas sin interés (tarjeta3=0) sigue vigente a precio de lista.
    expect(map['municion'], isA<Map>());
    final mun = map['municion'] as Map;
    expect(mun['efectivo'], 0);
    expect(mun['transferencia_como_efectivo'], isFalse);
    expect(mun['tarjeta3'], 0);
    expect(mun['tarjeta3_solo_arma_larga'], isTrue);
    // Recargos de tarjeta intactos.
    expect(map['tarjeta3'], 15);
    expect(map['tarjeta6'], 20);
    expect(map['tarjeta12'], 35);
  });
}
