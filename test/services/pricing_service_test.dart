import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
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

  test('precios fijos (Urban): se muestran tal cual, sin recalcular', () {
    const urbanProduct = Product(
      id: 'u',
      type: ProductType.armaLarga,
      marca: 'Sibian Armory',
      calibre: '.223',
      codigo: 'SIBIANFA15223',
      precioUsd: 3500,
      fixedPrices: FixedPrices(
        efectivoArs: 5495000,
        efectivoUsd: 3500,
        tarjetaArs: 5659850,
        cuota3Ars: 2058864.77,
        cuota6Ars: 1100463.50,
        cuota12Ars: 644232.43,
      ),
    );

    final exchange = ExchangeRateService(); // rate 1500 — NO debe usarse
    final settings = PricingSettingsService();

    final prices = PricingService().pricesFor(urbanProduct, exchange, settings);

    // Nada de tipo de cambio ni recargos: montos exactos del Excel.
    expect(prices.usd, 3500);
    expect(prices.efectivo, 5495000);
    expect(prices.lista, 5495000); // transferencia = efectivo
    expect(prices.transferencia, 5495000);
    expect(prices.debito, 0); // Urban no usa débito
    expect(prices.tarjeta1, 5659850); // PVP tarjeta 1 pago
    expect(prices.tarjeta3, closeTo(2058864.77 * 3, 0.01));
    expect(prices.cuota3, closeTo(2058864.77, 0.01));
    expect(prices.tarjeta6, closeTo(1100463.50 * 6, 0.01));
    expect(prices.tarjeta12, closeTo(644232.43 * 12, 0.01));
    expect(prices.tarjeta9, 0); // Urban no usa 9 cuotas
    expect(prices.tarjeta18, 0);

    exchange.dispose();
  });

  test('override munición: 10% efectivo/transf y 3 cuotas SI', () {
    const municion = Product(
      id: 'm',
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '.22',
      codigo: '960',
      precioUsd: 100,
    );
    const arma = Product(
      id: 'a',
      type: ProductType.armaLarga,
      marca: 'Rem',
      calibre: '.308',
      codigo: 'R1',
      precioUsd: 100,
    );

    final exchange = ExchangeRateService();
    final settings = PricingSettingsService()
      ..municionOverrideEnabled = true
      ..municionDescuentoEfectivoPct = 10
      ..municionRecargoTarjeta3Pct = 0
      ..municionTransferenciaComoEfectivo = true;

    final munPrices = PricingService().pricesFor(municion, exchange, settings);
    expect(munPrices.lista, 150000);
    expect(munPrices.efectivo, closeTo(135000, 0.01)); // -10%
    expect(munPrices.transferencia, closeTo(135000, 0.01));
    expect(munPrices.tarjeta3, closeTo(150000, 0.01)); // 0% SI
    expect(munPrices.tarjeta6, closeTo(180000, 0.01)); // global +20%

    final armaPrices = PricingService().pricesFor(arma, exchange, settings);
    expect(armaPrices.efectivo, closeTo(142500, 0.01)); // global -5%
    expect(armaPrices.transferencia, 150000); // lista
    expect(armaPrices.tarjeta3, closeTo(172500, 0.01)); // global +15%

    exchange.dispose();
  });
}
