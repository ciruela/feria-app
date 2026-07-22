import '../models/invoice.dart';
import '../config/payment_config.dart';
import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';

class InvoiceService {
  InvoiceService({PricingService? pricing})
      : _pricing = pricing ?? PricingService();

  final PricingService _pricing;

  Invoice buildFromCart({
    required String buyerFullName,
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    SellerService? sellerService,
  }) {
    final method = cart.checkoutPayment?.pricingMethod ?? defaultPaymentMethod;
    final lines = <InvoiceLine>[];
    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final prices = _pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      final lineUsd = prices.usd * item.quantity;
      final lineArs = method.totalArsFor(prices) * item.quantity;

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
          paymentMethod: method,
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
