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
    // Urban Tactical: precios fijos del Excel. No se recalcula nada.
    final fixed = product.fixedPrices;
    if (fixed != null) {
      return _fromFixed(product, fixed);
    }

    final lista = exchangeRate.toArs(product.precioUsd);
    final efectivoPct = settings.descuentoEfectivoPctFor(product.type);
    final tarjeta3Pct = settings.recargoTarjeta3PctFor(product.type);
    final efectivo = lista * (1 - efectivoPct / 100);
    final transferencia = settings.transferenciaComoEfectivoFor(product.type)
        ? efectivo
        : lista;

    return ProductPrices(
      usd: product.precioUsd,
      lista: lista,
      efectivo: efectivo,
      transferencia: transferencia,
      debito: lista * (1 + settings.recargoDebitoPct / 100),
      tarjeta1: lista * (1 + settings.recargoTarjeta1Pct / 100),
      tarjeta3: lista * (1 + tarjeta3Pct / 100),
      tarjeta6: lista * (1 + settings.recargoTarjeta6Pct / 100),
      tarjeta9: lista * (1 + settings.recargoTarjeta9Pct / 100),
      tarjeta12: lista * (1 + settings.recargoTarjeta12Pct / 100),
      tarjeta18: lista * (1 + settings.recargoTarjeta18Pct / 100),
    );
  }

  /// Mapea los precios fijos del Excel a [ProductPrices] sin cálculo alguno.
  ///
  /// Urban maneja: efectivo/transferencia, 1 pago con tarjeta y 3/6/12 cuotas.
  /// Los métodos que Urban no usa (débito, 1/9/18 cuotas) quedan en 0 y las
  /// vistas fieles no los muestran.
  ProductPrices _fromFixed(Product product, FixedPrices f) {
    final efectivo = f.efectivoArs ?? 0;
    return ProductPrices(
      usd: f.efectivoUsd ?? product.precioUsd,
      lista: efectivo, // transferencia/lista = efectivo en el Excel de Urban
      efectivo: efectivo,
      transferencia: efectivo,
      debito: 0,
      tarjeta1: f.tarjetaArs ?? 0,
      tarjeta3: f.tarjeta3Total ?? 0,
      tarjeta6: f.tarjeta6Total ?? 0,
      tarjeta9: 0,
      tarjeta12: f.tarjeta12Total ?? 0,
      tarjeta18: 0,
    );
  }
}
