import '../models/cart_checkout_payment.dart';
import '../models/product_prices.dart';
import 'cart_service.dart';
import 'exchange_rate_service.dart';
import 'pricing_service.dart';
import 'pricing_settings_service.dart';

class CartLineTotal {
  const CartLineTotal({
    required this.usd,
    required this.ars,
  });

  final double usd;
  final double ars;
}

class CartTotalsService {
  CartTotalsService({PricingService? pricing})
      : _pricing = pricing ?? PricingService();

  final PricingService _pricing;

  CartLineTotal lineTotal({
    required CartItem item,
    required PaymentMethod method,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
  }) {
    final prices = _pricing.pricesFor(
      item.product,
      exchangeRate,
      pricingSettings,
    );
    return CartLineTotal(
      usd: prices.usd * item.quantity,
      ars: method.totalArsFor(prices) * item.quantity,
    );
  }

  CartLineTotal cartTotalAtMethod({
    required CartService cart,
    required PaymentMethod method,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
  }) {
    var usd = 0.0;
    var ars = 0.0;

    for (final item in cart.items) {
      final line = lineTotal(
        item: item,
        method: method,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      usd += line.usd;
      ars += line.ars;
    }

    return CartLineTotal(usd: usd, ars: ars);
  }

  List<PaymentAllocation> allocationsFor({
    required CartCheckoutPayment checkout,
    required CartLineTotal total,
  }) {
    if (!checkout.isDual) {
      return [
        PaymentAllocation(
          method: checkout.pricingMethod,
          amountUsd: checkout.pricingMethod.isUsdPayment ? total.usd : 0,
          amountArs: checkout.pricingMethod.isUsdPayment ? 0 : total.ars,
        ),
      ];
    }

    final primary = checkout.pricingMethod;
    final secondary = checkout.secondMethod!;
    final share = checkout.primaryShare;

    if (primary.isUsdPayment) {
      return [
        PaymentAllocation(
          method: primary,
          amountUsd: total.usd * share,
          amountArs: 0,
        ),
        PaymentAllocation(
          method: secondary,
          amountUsd: total.usd * (1 - share),
          amountArs: 0,
        ),
      ];
    }

    return [
      PaymentAllocation(
        method: primary,
        amountUsd: 0,
        amountArs: total.ars * share,
      ),
      PaymentAllocation(
        method: secondary,
        amountUsd: 0,
        amountArs: total.ars * (1 - share),
      ),
    ];
  }
}
