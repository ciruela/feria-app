import 'package:app_feria/models/budget.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_product.dart';

BudgetLine _line({
  required String key,
  required PaymentMethod method,
  double ars = 0,
  double usd = 0,
}) {
  return BudgetLine(
    lineKey: key,
    productId: key,
    code: key,
    quantity: 1,
    detail: '',
    unitArs: ars,
    lineArs: ars,
    unitUsd: usd,
    lineUsd: usd,
    paymentMethod: method,
    isArma: false,
  );
}

void main() {
  late CartTotalsService totals;
  late ExchangeRateService exchangeRate;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    totals = CartTotalsService();
    exchangeRate = ExchangeRateService(); // rate por defecto = 1500
  });

  group('allocationsFromLines', () {
    test('lista vacía -> sin allocations', () {
      expect(totals.allocationsFromLines([], exchangeRate: exchangeRate),
          isEmpty);
    });

    test('agrupa dos métodos ARS con montos REALES por línea', () {
      final lines = [
        _line(key: 'a', method: PaymentMethod.tarjeta3, ars: 100000),
        _line(key: 'b', method: PaymentMethod.efectivo, ars: 50000),
      ];

      final allocs =
          totals.allocationsFromLines(lines, exchangeRate: exchangeRate);

      expect(allocs, hasLength(2));
      final tarjeta = allocs.firstWhere((a) => a.method == PaymentMethod.tarjeta3);
      final efectivo = allocs.firstWhere((a) => a.method == PaymentMethod.efectivo);
      // Cada medio lleva EXACTAMENTE el monto de su propia línea.
      expect(tarjeta.amountArs, 100000);
      expect(efectivo.amountArs, 50000);
      expect(tarjeta.amountUsd, 0);
      expect(efectivo.amountUsd, 0);
      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
    });

    test('suma varias líneas del mismo método', () {
      final lines = [
        _line(key: 'a', method: PaymentMethod.efectivo, ars: 30000),
        _line(key: 'b', method: PaymentMethod.efectivo, ars: 20000),
        _line(key: 'c', method: PaymentMethod.tarjeta6, ars: 90000),
      ];

      final allocs =
          totals.allocationsFromLines(lines, exchangeRate: exchangeRate);

      expect(allocs, hasLength(2));
      expect(
        allocs.firstWhere((a) => a.method == PaymentMethod.efectivo).amountArs,
        50000,
      );
      expect(
        allocs.firstWhere((a) => a.method == PaymentMethod.tarjeta6).amountArs,
        90000,
      );
    });

    test('mezcla USD + ARS: cada medio en su moneda, share con tipo de cambio',
        () {
      final lines = [
        _line(key: 'a', method: PaymentMethod.dolarBillete, usd: 100),
        _line(key: 'b', method: PaymentMethod.efectivo, ars: 150000),
      ];

      final allocs =
          totals.allocationsFromLines(lines, exchangeRate: exchangeRate);

      final usd = allocs.firstWhere((a) => a.method == PaymentMethod.dolarBillete);
      final ars = allocs.firstWhere((a) => a.method == PaymentMethod.efectivo);
      expect(usd.amountUsd, 100);
      expect(usd.amountArs, 0);
      expect(ars.amountArs, 150000);
      expect(ars.amountUsd, 0);
      // Base común: 100*1500 = 150000 == 150000 -> 50/50.
      expect(usd.share, closeTo(0.5, 0.0001));
      expect(ars.share, closeTo(0.5, 0.0001));
      expect(usd.share + ars.share, closeTo(1.0, 0.0001));
    });
  });

  group('allocationsForCart (preview del carrito)', () {
    late CartService cart;
    late PricingSettingsService settings;

    setUp(() {
      cart = CartService();
      settings = PricingSettingsService();
    });

    test('cada ítem con su método -> una allocation por método', () {
      cart.addProduct(testProduct(id: 'a', precioUsd: 100));
      cart.addProduct(testProduct(id: 'b', precioUsd: 50));
      final keys = {for (final i in cart.items) i.product.id: i.lineKey};
      cart.setLinePaymentMethod(keys['a']!, PaymentMethod.tarjeta3);
      cart.setLinePaymentMethod(keys['b']!, PaymentMethod.efectivo);

      final allocs = totals.allocationsForCart(
        cart: cart,
        fallbackMethod: PaymentMethod.transferencia,
        exchangeRate: exchangeRate,
        pricingSettings: settings,
      );

      expect(allocs, hasLength(2));
      expect(
        allocs.map((a) => a.method).toSet(),
        {PaymentMethod.tarjeta3, PaymentMethod.efectivo},
      );
      expect(allocs.every((a) => a.amountArs > 0), isTrue);
    });

    test('ítems sin método usan el fallback (se agrupan en un método)', () {
      cart.addProduct(testProduct(id: 'a', precioUsd: 100));
      cart.addProduct(testProduct(id: 'b', precioUsd: 50));

      final allocs = totals.allocationsForCart(
        cart: cart,
        fallbackMethod: PaymentMethod.transferencia,
        exchangeRate: exchangeRate,
        pricingSettings: settings,
      );

      expect(allocs, hasLength(1));
      expect(allocs.single.method, PaymentMethod.transferencia);
      expect(allocs.single.share, closeTo(1.0, 0.0001));
    });
  });
}
