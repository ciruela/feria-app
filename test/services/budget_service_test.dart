import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/budget_service.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_product.dart';

void main() {
  late BudgetService budgetService;
  late CartService cart;
  late ExchangeRateService exchangeRate;
  late PricingSettingsService settings;

  setUp(() {
    final pricing = PricingService();
    budgetService = BudgetService(
      pricing: pricing,
      cartTotals: CartTotalsService(pricing: pricing),
    );
    cart = CartService();
    exchangeRate = ExchangeRateService();
    settings = PricingSettingsService();
  });

  test('builds lines and payment allocations with checkout', () {
    cart.addProduct(testProduct(id: 'a', precioUsd: 100));
    cart.addProduct(testProduct(id: 'b', precioUsd: 50));
    cart.setCheckoutPayment(
      CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.transferencia,
        secondMethod: PaymentMethod.efectivo,
        primaryShare: 0.6,
      ),
    );

    final budget = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    expect(budget.lines, hasLength(2));
    expect(budget.paymentAllocations, hasLength(2));
  });

  test('preview budget uses transferencia when checkout is missing', () {
    cart.addProduct(testProduct(id: 'a', precioUsd: 100));

    final budget = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    expect(budget.lines, hasLength(1));
    expect(budget.lines.first.paymentMethod, PaymentMethod.transferencia);
    expect(budget.paymentAllocations, isEmpty);
  });
}
