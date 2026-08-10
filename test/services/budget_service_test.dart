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

  test('medio de pago por línea: cada producto se precia con SU método', () {
    // Caso real: caj\u00f3n en 3 cuotas + munici\u00f3n en efectivo, sin que el
    // descuento de efectivo contamine al caj\u00f3n (ni el recargo al rev\u00e9s).
    cart.addProduct(testProduct(id: 'cajon', precioUsd: 440));
    cart.addProduct(testProduct(id: 'cajas', precioUsd: 380));
    final keys = {
      for (final item in cart.items) item.product.id: item.lineKey,
    };

    double lineArsOf(budget, String productId) =>
        budget.lines.firstWhere((l) => l.productId == productId).lineArs;

    // Referencia: todo en 3 cuotas.
    cart.setLinePaymentMethod(keys['cajon']!, PaymentMethod.tarjeta3);
    cart.setLinePaymentMethod(keys['cajas']!, PaymentMethod.tarjeta3);
    final allTarjeta3 = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    // Referencia: todo en efectivo.
    cart.setLinePaymentMethod(keys['cajon']!, PaymentMethod.efectivo);
    cart.setLinePaymentMethod(keys['cajas']!, PaymentMethod.efectivo);
    final allEfectivo = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    // Mezcla: caj\u00f3n en 3 cuotas, cajas en efectivo.
    cart.setLinePaymentMethod(keys['cajon']!, PaymentMethod.tarjeta3);
    cart.setLinePaymentMethod(keys['cajas']!, PaymentMethod.efectivo);
    final mixed = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    // El test es significativo solo si ambos métodos dan precios distintos.
    expect(lineArsOf(allEfectivo, 'cajon'),
        isNot(lineArsOf(allTarjeta3, 'cajon')));

    // Cada línea de la mezcla usa EXACTAMENTE el precio de su propio método.
    expect(lineArsOf(mixed, 'cajon'), lineArsOf(allTarjeta3, 'cajon'));
    expect(lineArsOf(mixed, 'cajas'), lineArsOf(allEfectivo, 'cajas'));

    // Las allocations salen de las líneas (montos reales, no share global).
    expect(mixed.paymentAllocations, hasLength(2));
    expect(
      mixed.paymentAllocations.map((a) => a.method).toSet(),
      {PaymentMethod.tarjeta3, PaymentMethod.efectivo},
    );
    final sumaArs = mixed.paymentAllocations
        .fold<double>(0, (s, a) => s + a.amountArs);
    expect(sumaArs,
        closeTo(lineArsOf(mixed, 'cajon') + lineArsOf(mixed, 'cajas'), 0.001));
  });

  test('sin método por línea: mantiene el share del checkout (no-regresión)',
      () {
    cart.addProduct(testProduct(id: 'a', precioUsd: 100));
    cart.addProduct(testProduct(id: 'b', precioUsd: 50));
    cart.setCheckoutPayment(
      const CartCheckoutPayment.dual(
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

    // Ambas líneas siguen el método global (no hay override por línea).
    expect(
      budget.lines.every((l) => l.paymentMethod == PaymentMethod.transferencia),
      isTrue,
    );
    expect(budget.paymentAllocations, hasLength(2));
    expect(
      budget.paymentAllocations[0].share + budget.paymentAllocations[1].share,
      closeTo(1.0, 0.0001),
    );
  });

  test('Urban Bersa: USD 0 with fixed ARS still builds sellable lines', () {
    const bersa = Product(
      id: 'bersa_1',
      type: ProductType.armaCorta,
      marca: 'BERSA',
      calibre: '9',
      codigo: '0T9',
      modelo: 'TPR9',
      precioUsd: 0,
      stock: 5,
      fixedPrices: FixedPrices(efectivoArs: 500000, tarjetaArs: 520000),
    );
    expect(cart.addProduct(bersa), CartAddResult.added);
    cart.setCheckoutPayment(
      const CartCheckoutPayment.single(PaymentMethod.efectivo),
    );

    final budget = budgetService.buildFromCart(
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: settings,
    );

    expect(budget.lines, hasLength(1));
    expect(budget.lines.single.unitUsd, 0);
    expect(budget.lines.single.unitArs, 500000);
    // Criterio de checkout: alcanza con ARS > 0 (no exigir USD).
    expect(
      budget.lines.any((line) => line.unitArs <= 0 && line.unitUsd <= 0),
      isFalse,
    );
  });
}
