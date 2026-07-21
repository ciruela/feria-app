import '../models/invoice.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';

class InvoiceService {
  Invoice buildFromCart({
    required String buyerFullName,
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    SellerService? sellerService,
  }) {
    final pricing = PricingService();
    final lines = <InvoiceLine>[];
    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final prices = pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      final lineUsd = prices.usd * item.quantity;
      final lineArs = item.paymentMethod.totalArsFor(prices) * item.quantity;

      totalUsd += lineUsd;
      totalArs += lineArs;

      lines.add(
        InvoiceLine(
          productName: item.product.invoiceProductName,
          internalCode: item.product.id,
          productCode: item.product.codigo.isNotEmpty
              ? item.product.codigo
              : item.product.modeloDisplay,
          quantity: item.quantity,
          paymentMethod: item.paymentMethod,
          lineUsd: lineUsd,
          lineArs: lineArs,
        ),
      );
    }

    return Invoice(
      buyerFullName: buyerFullName.trim(),
      date: DateTime.now(),
      sellerName: sellerService?.selected?.nombre,
      lines: lines,
      totalUsd: totalUsd,
      totalArs: totalArs,
    );
  }
}
