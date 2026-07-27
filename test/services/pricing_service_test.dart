import 'package:app_feria/models/product.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = Product(
    id: 'p',
    type: ProductType.armaCorta,
    marca: 'Glock',
    calibre: '9',
    codigo: 'G17',
    precioUsd: 100,
  );

  test('pricesFor aplica tipo de cambio y recargos por defecto', () {
    final exchange = ExchangeRateService(); // rate por defecto = 1500
    final settings = PricingSettingsService(); // recargos por defecto

    final prices = PricingService().pricesFor(product, exchange, settings);

    expect(prices.usd, 100);
    expect(prices.lista, 150000); // 100 * 1500
    expect(prices.efectivo, closeTo(142500, 0.01)); // -5%
    expect(prices.debito, closeTo(157500, 0.01)); // +5%
    expect(prices.tarjeta1, closeTo(165000, 0.01)); // +10%
    expect(prices.tarjeta3, closeTo(172500, 0.01)); // +15%
    expect(prices.tarjeta6, closeTo(180000, 0.01)); // +20%
    expect(prices.tarjeta9, closeTo(195000, 0.01)); // +30%
    expect(prices.tarjeta12, closeTo(202500, 0.01)); // +35%
    expect(prices.tarjeta18, closeTo(217500, 0.01)); // +45%

    exchange.dispose();
  });

  test('toArs multiplica por el tipo de cambio por defecto', () {
    final exchange = ExchangeRateService();
    expect(exchange.rate, ExchangeRateService.defaultRate);
    expect(exchange.toArs(2), 3000);
    exchange.dispose();
  });
}
