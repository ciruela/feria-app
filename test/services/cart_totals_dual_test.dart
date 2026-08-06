import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartTotalsService.allocationsFor dual', () {
    final totals = CartTotalsService();
    const total = CartLineTotal(usd: 100, ars: 150000);

    test('USD + ARS: shares suman 1 y cada medio usa su moneda', () {
      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.dolarBillete,
        secondMethod: PaymentMethod.efectivo,
        primaryShare: 0.6,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);
      expect(allocs.length, 2);
      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
      expect(allocs[0].amountUsd, closeTo(60, 0.001));
      expect(allocs[0].amountArs, 0);
      expect(allocs[1].amountUsd, 0);
      expect(allocs[1].amountArs, closeTo(60000, 0.001));
    });

    test('ARS + ARS: ambos en pesos con shares', () {
      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.efectivo,
        secondMethod: PaymentMethod.transferencia,
        primaryShare: 0.4,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);
      expect(allocs[0].amountArs, closeTo(60000, 0.001));
      expect(allocs[1].amountArs, closeTo(90000, 0.001));
      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
    });
  });
}
