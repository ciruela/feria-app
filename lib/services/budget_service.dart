import '../config/payment_config.dart';
import '../models/budget.dart';
import '../models/cart_checkout_payment.dart';
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

    /// Urban: marca/modelo/calibre sin descripción larga.
    bool compactLineDetail = false,
  }) {
    // AR-41: series por unidad — arma con qty>1 se parte antes de armar líneas.
    cart.ensureWeaponsAreUnitLines();

    final checkout = cart.checkoutPayment;
    final fallbackMethod = checkout?.pricingMethod ?? defaultPaymentMethod;
    // AR: cada línea puede tener su propio medio (promo + dos medios). Si al
    // menos una lo define, el reparto sale de las líneas (montos reales) en vez
    // del share global del checkout.
    final hasPerLineMethods =
        cart.items.any((item) => item.paymentMethod != null);
    final lines = <BudgetLine>[];
    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final method = item.paymentMethod ?? fallbackMethod;
      final prices = _pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
        applyDiscounts: cart.applyDiscounts,
      );
      final unitUsd = method.totalUsdFor(prices);
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
          detail: item.product.budgetDetailForReceipt(
            compact: compactLineDetail,
          ),
          unitArs: unitArs,
          lineArs: lineArs,
          unitUsd: unitUsd,
          lineUsd: lineUsd,
          listaArs: prices.lista * item.quantity,
          paymentMethod: method,
          isArma: item.product.isArma,
          serialNumber: item.serialNumber,
          tarjetaConsumo: item.tarjetaConsumo,
          productType: item.product.type.key,
        ),
      );
    }

    final List<PaymentAllocation> allocations;
    if (hasPerLineMethods) {
      allocations = _cartTotals.allocationsFromLines(
        lines,
        exchangeRate: exchangeRate,
      );
    } else if (checkout == null) {
      allocations = const <PaymentAllocation>[];
    } else {
      allocations = _cartTotals.allocationsFor(
        checkout: checkout,
        total: _cartTotals.cartTotalAtMethod(
          cart: cart,
          method: fallbackMethod,
          exchangeRate: exchangeRate,
          pricingSettings: pricingSettings,
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
      paymentAllocations: allocations,
    );
  }
}
