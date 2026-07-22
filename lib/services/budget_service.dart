import '../models/budget.dart';
import 'cart_service.dart';
import 'exchange_rate_service.dart';
import 'pricing_service.dart';
import 'pricing_settings_service.dart';
import 'seller_service.dart';

class BudgetService {
  Budget buildFromCart({
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    BudgetCustomer customer = const BudgetCustomer(),
    SellerService? sellerService,
  }) {
    final pricing = PricingService();
    final lines = <BudgetLine>[];
    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final prices = pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      final share = item.paymentShare;
      final unitUsd = prices.usd * share;
      final unitArs = item.paymentMethod.totalArsFor(prices) * share;
      final lineUsd = unitUsd * item.quantity;
      final lineArs = unitArs * item.quantity;

      totalUsd += lineUsd;
      totalArs += lineArs;

      var detail = item.product.budgetDetail();
      if (item.isSplitPart) {
        detail =
            '$detail · Pago ${item.splitPart}/2 (${item.paymentMethod.shortLabel})';
      }

      lines.add(
        BudgetLine(
          lineKey: item.lineKey,
          productId: item.product.id,
          code: item.product.budgetCode,
          quantity: item.quantity,
          detail: detail,
          unitArs: unitArs,
          lineArs: lineArs,
          unitUsd: unitUsd,
          lineUsd: lineUsd,
          paymentMethod: item.paymentMethod,
          isArma: item.product.isArma,
          serialNumber: item.serialNumber,
          splitPart: item.splitPart,
          productType: item.product.type.key,
        ),
      );
    }

    return Budget(
      date: DateTime.now(),
      customer: customer,
      sellerName: sellerService?.selected?.nombre,
      lines: lines,
      totalUsd: totalUsd,
      totalArs: totalArs,
    );
  }
}
