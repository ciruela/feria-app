import '../models/product.dart';
import '../models/product_prices.dart';
import 'exchange_rate_service.dart';
import 'pricing_settings_service.dart';

class PricingService {
  ProductPrices pricesFor(
    Product product,
    ExchangeRateService exchangeRate,
    PricingSettingsService settings,
  ) {
    final lista = exchangeRate.toArs(product.precioUsd);
    final efectivo = lista * (1 - settings.descuentoEfectivoPct / 100);
    final tarjeta3 = lista * (1 + settings.recargoTarjeta3Pct / 100);
    final tarjeta6 = lista * (1 + settings.recargoTarjeta6Pct / 100);
    final tarjeta12 = lista * (1 + settings.recargoTarjeta12Pct / 100);

    return ProductPrices(
      usd: product.precioUsd,
      lista: lista,
      efectivo: efectivo,
      tarjeta3: tarjeta3,
      tarjeta6: tarjeta6,
      tarjeta12: tarjeta12,
    );
  }
}
