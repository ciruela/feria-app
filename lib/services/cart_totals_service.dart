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
      usd: method.totalUsdFor(prices) * item.quantity,
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

  /// True si todos los ítems tienen monto USD > 0 para cobro en dólar billete.
  ///
  /// Evita ofrecer USD en Urban cuando el Excel solo trae ARS (efectivo_usd = 0).
  bool cartSupportsUsdCheckout({
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
  }) {
    if (cart.items.isEmpty) return false;
    for (final item in cart.items) {
      final line = lineTotal(
        item: item,
        method: PaymentMethod.dolarBillete,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      if (line.usd <= 0) return false;
    }
    return true;
  }

  /// Asigna montos y [PaymentAllocation.share] (suma 1) para register_sale.
  /// Dual USD+ARS: cada medio lleva su moneda con la porción de venta.
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
          share: 1.0,
        ),
      ];
    }

    final primary = checkout.pricingMethod;
    final secondary = checkout.secondMethod!;
    final share = checkout.primaryShare.clamp(0.05, 0.95);
    final rest = 1.0 - share;

    return [
      PaymentAllocation(
        method: primary,
        amountUsd: primary.isUsdPayment ? total.usd * share : 0,
        amountArs: primary.isUsdPayment ? 0 : total.ars * share,
        share: share,
      ),
      PaymentAllocation(
        method: secondary,
        amountUsd: secondary.isUsdPayment ? total.usd * rest : 0,
        amountArs: secondary.isUsdPayment ? 0 : total.ars * rest,
        share: rest,
      ),
    ];
  }
}
