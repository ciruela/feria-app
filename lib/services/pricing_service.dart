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

    return ProductPrices(
      usd: product.precioUsd,
      lista: lista,
      efectivo: efectivo,
      debito: lista * (1 + settings.recargoDebitoPct / 100),
      tarjeta1: lista * (1 + settings.recargoTarjeta1Pct / 100),
      tarjeta3: lista * (1 + settings.recargoTarjeta3Pct / 100),
      tarjeta6: lista * (1 + settings.recargoTarjeta6Pct / 100),
      tarjeta9: lista * (1 + settings.recargoTarjeta9Pct / 100),
      tarjeta12: lista * (1 + settings.recargoTarjeta12Pct / 100),
      tarjeta18: lista * (1 + settings.recargoTarjeta18Pct / 100),
    );
  }
}
