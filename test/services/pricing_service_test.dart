import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_product.dart';

void main() {
  late PricingService pricing;
  late ExchangeRateService exchangeRate;
  late PricingSettingsService settings;

  setUp(() {
    pricing = PricingService();
    exchangeRate = ExchangeRateService();
    settings = PricingSettingsService();
  });

  test('calculates lista from USD and exchange rate', () {
    final product = testProduct(precioUsd: 100);
    final prices = pricing.pricesFor(product, exchangeRate, settings);

    expect(prices.usd, 100);
    expect(prices.lista, 100 * ExchangeRateService.defaultRate);
  });

  test('applies efectivo discount', () {
    final product = testProduct(precioUsd: 100);
    final prices = pricing.pricesFor(product, exchangeRate, settings);

    expect(
      prices.efectivo,
      closeTo(prices.lista * (1 - settings.descuentoEfectivoPct / 100), 0.01),
    );
    expect(
      PaymentMethod.efectivo.totalArsFor(prices),
      closeTo(prices.efectivo, 0.01),
    );
  });

  test('transferencia equals lista price', () {
    final product = testProduct(precioUsd: 50);
    final prices = pricing.pricesFor(product, exchangeRate, settings);

    expect(
      PaymentMethod.transferencia.totalArsFor(prices),
      prices.lista,
    );
  });

  test('applies tarjeta recargos', () {
    final product = testProduct(precioUsd: 100);
    final prices = pricing.pricesFor(product, exchangeRate, settings);

    expect(prices.tarjeta1, closeTo(prices.lista * 1.10, 0.01));
    expect(prices.tarjeta3, closeTo(prices.lista * 1.15, 0.01));
    expect(prices.tarjeta6, closeTo(prices.lista * 1.20, 0.01));
  });
}
