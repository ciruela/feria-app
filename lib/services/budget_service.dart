import '../config/payment_config.dart';
import '../models/budget.dart';
import '../models/cart_checkout_payment.dart';
import '../models/product_prices.dart';
import 'cart_service.dart';
import 'cart_totals_service.dart';
import 'exchange_rate_service.dart';
import 'pricing_service.dart';
import 'pricing_settings_service.dart';
import 'seller_service.dart';

class BudgetService {
  BudgetService({
    PricingService? pricing,
    CartTotalsService? cartTotals,
  })  : _pricing = pricing ?? PricingService(),
        _cartTotals = cartTotals ??
            CartTotalsService(pricing: pricing ?? PricingService());

  final PricingService _pricing;
  final CartTotalsService _cartTotals;

  Budget buildFromCart({
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    BudgetCustomer customer = const BudgetCustomer(),
    SellerService? sellerService,
  }) {
    final checkout = cart.checkoutPayment;
    final method = checkout?.pricingMethod ?? defaultPaymentMethod;
    final lines = <BudgetLine>[];
    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final prices = _pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      final unitUsd = prices.usd;
      final unitArs = method.totalArsFor(prices);
      final lineUsd = unitUsd * item.quantity;
      final lineArs = unitArs * item.quantity;

      totalUsd += lineUsd;
      totalArs += lineArs;

      lines.add(
        BudgetLine(
          lineKey: item.lineKey,
          productId: item.product.id,
          code: item.product.budgetCode,
          quantity: item.quantity,
          detail: item.product.budgetDetail(),
          unitArs: unitArs,
          lineArs: lineArs,
          unitUsd: unitUsd,
          lineUsd: lineUsd,
          paymentMethod: method,
          isArma: item.product.isArma,
          serialNumber: item.serialNumber,
          productType: item.product.type.key,
        ),
      );
    }

    final allocations = checkout == null
        ? const <PaymentAllocation>[]
        : _cartTotals.allocationsFor(
            checkout: checkout,
            total: _cartTotals.cartTotalAtMethod(
              cart: cart,
              method: method,
              exchangeRate: exchangeRate,
              pricingSettings: pricingSettings,
            ),
          );

    return Budget(
      date: DateTime.now(),
      customer: customer,
      sellerName: sellerService?.selected?.nombre,
      lines: lines,
      totalUsd: totalUsd,
      totalArs: totalArs,
      paymentAllocations: allocations,
    );
  }
}
