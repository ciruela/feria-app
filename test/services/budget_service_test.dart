import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/budget_service.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_product.dart';

void main() {
  late BudgetService budgetService;
  late CartService cart;
  late ExchangeRateService exchangeRate;
  late PricingSettingsService settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    const payment = CartCheckoutPayment.dual(
      pricingMethod: PaymentMethod.transferencia,
      secondMethod: PaymentMethod.efectivo,
      primaryShare: 0.6,
    );
    cart.setCheckoutPayment(payment);

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

  test('two identical weapons become individual budget lines (AR-41)', () {
    final weapon = testProduct(
      id: 'arma1',
      precioUsd: 500,
      type: ProductType.armaCorta,
      stock: 5,
    );
    expect(cart.addProductQuantity(weapon, 2), CartAddResult.added);

    final budget = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    expect(budget.lines, hasLength(2));
    expect(budget.lines.every((line) => line.quantity == 1), isTrue);
    expect(budget.lines.every((line) => line.isArma), isTrue);
    expect(budget.lines[0].lineKey, isNot(budget.lines[1].lineKey));
    expect(budget.lines[0].productId, budget.lines[1].productId);
  });

  test('compactLineDetail omits full product description', () {
    cart.addProduct(
      testProduct(
        id: 'arma1',
        precioUsd: 500,
        type: ProductType.armaCorta,
        marca: 'GLOCK',
        modelo: '19',
        calibre: '9mm',
        descripcion: 'DESCRIPCION LARGA QUE NO DEBE IR EN URBAN',
      ),
    );

    final full = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );
    final compact = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
      compactLineDetail: true,
    );

    expect(full.lines.first.detail, contains('DESCRIPCION LARGA'));
    expect(compact.lines.first.detail, isNot(contains('DESCRIPCION LARGA')));
    expect(compact.lines.first.detail, contains('GLOCK'));
    expect(compact.lines.first.detail, contains('19'));
    expect(compact.lines.first.detail, contains('9mm'));
  });
}
