import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_product.dart';

void main() {
  late PricingService pricing;
  late CartTotalsService totalsService;
  late ExchangeRateService exchangeRate;
  late PricingSettingsService settings;
  late CartService cart;

  setUp(() {
    pricing = PricingService();
    totalsService = CartTotalsService(pricing: pricing);
    exchangeRate = ExchangeRateService();
    settings = PricingSettingsService();
    cart = CartService();
  });

  test('sums cart total at chosen payment method', () {
    cart.addProduct(testProduct(id: 'a', precioUsd: 100));
    cart.addProduct(testProduct(id: 'b', precioUsd: 50));

    final total = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.transferencia,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    final expectedLista = (100 + 50) * ExchangeRateService.defaultRate;
    expect(total.usd, 150);
    expect(total.ars, expectedLista);
  });

  test('allocates dual payment in ARS', () {
    cart.addProduct(testProduct(precioUsd: 100));

    final total = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.transferencia,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    final checkout = CartCheckoutPayment.dual(
      pricingMethod: PaymentMethod.transferencia,
      secondMethod: PaymentMethod.efectivo,
      primaryShare: 0.6,
    );

    final allocations = totalsService.allocationsFor(
      checkout: checkout,
      total: total,
    );

    expect(allocations, hasLength(2));
    expect(allocations[0].amountArs, closeTo(total.ars * 0.6, 0.01));
    expect(allocations[1].amountArs, closeTo(total.ars * 0.4, 0.01));
  });

  test('tracks weapons missing serial number', () {
    cart.addProduct(
      testProduct(id: 'arma', precioUsd: 200, type: ProductType.armaCorta),
    );
    cart.addProduct(testProduct(id: 'muni', precioUsd: 10));

    expect(cart.weaponsMissingSerial, hasLength(1));

    cart.updateSerialNumber('arma', 'ABC123');
    expect(cart.weaponsMissingSerial, isEmpty);
  });
}
