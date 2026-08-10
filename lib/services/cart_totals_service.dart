import '../models/budget.dart';
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

  /// Reparte por medio de pago sumando los montos REALES de cada línea (no un
  /// porcentaje del total). Habilita "cada producto con su método": p. ej. un
  /// arma en 3 cuotas y munición en efectivo, sin contaminar el descuento.
  ///
  /// Los montos por moneda quedan exactos. [PaymentAllocation.share] es solo la
  /// proporción de la venta (suma 1); para mezclar monedas usa el tipo de
  /// cambio como base común, sin alterar los montos.
  List<PaymentAllocation> allocationsFromLines(
    List<BudgetLine> lines, {
    required ExchangeRateService exchangeRate,
  }) {
    if (lines.isEmpty) return const [];

    final order = <PaymentMethod>[];
    final usdByMethod = <PaymentMethod, double>{};
    final arsByMethod = <PaymentMethod, double>{};
    final listaByMethod = <PaymentMethod, double>{};

    for (final line in lines) {
      final method = line.paymentMethod;
      if (!order.contains(method)) order.add(method);
      listaByMethod[method] = (listaByMethod[method] ?? 0) + line.listaArs;
      if (line.paysInUsd) {
        usdByMethod[method] = (usdByMethod[method] ?? 0) + line.lineUsd;
      } else {
        arsByMethod[method] = (arsByMethod[method] ?? 0) + line.lineArs;
      }
    }

    return _groupedAllocations(
      order,
      usdByMethod,
      arsByMethod,
      exchangeRate.rate,
      listaByMethod: listaByMethod,
    );
  }

  /// Igual que [allocationsFromLines] pero directo desde el carrito, para el
  /// preview de totales antes de armar el presupuesto. Cada ítem se precia con
  /// `item.paymentMethod ?? fallbackMethod`.
  List<PaymentAllocation> allocationsForCart({
    required CartService cart,
    required PaymentMethod fallbackMethod,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
  }) {
    if (cart.items.isEmpty) return const [];

    final order = <PaymentMethod>[];
    final usdByMethod = <PaymentMethod, double>{};
    final arsByMethod = <PaymentMethod, double>{};
    final listaByMethod = <PaymentMethod, double>{};

    for (final item in cart.items) {
      final method = item.paymentMethod ?? fallbackMethod;
      final prices =
          _pricing.pricesFor(item.product, exchangeRate, pricingSettings);
      if (!order.contains(method)) order.add(method);
      listaByMethod[method] =
          (listaByMethod[method] ?? 0) + prices.lista * item.quantity;
      if (method.isUsdPayment) {
        usdByMethod[method] =
            (usdByMethod[method] ?? 0) + method.totalUsdFor(prices) * item.quantity;
      } else {
        arsByMethod[method] =
            (arsByMethod[method] ?? 0) + method.totalArsFor(prices) * item.quantity;
      }
    }

    return _groupedAllocations(
      order,
      usdByMethod,
      arsByMethod,
      exchangeRate.rate,
      listaByMethod: listaByMethod,
    );
  }

  /// Construye las allocations (montos exactos por moneda) y calcula el `share`
  /// (0–1, suma 1) usando el tipo de cambio solo como base común entre monedas.
  List<PaymentAllocation> _groupedAllocations(
    List<PaymentMethod> order,
    Map<PaymentMethod, double> usdByMethod,
    Map<PaymentMethod, double> arsByMethod,
    double rate, {
    Map<PaymentMethod, double> listaByMethod = const {},
  }) {
    double baseOf(PaymentMethod method) {
      final usd = usdByMethod[method] ?? 0;
      final ars = arsByMethod[method] ?? 0;
      return ars + (rate > 0 ? usd * rate : 0);
    }

    final totalBase =
        order.fold<double>(0, (sum, method) => sum + baseOf(method));

    return [
      for (final method in order)
        PaymentAllocation(
          method: method,
          amountUsd: usdByMethod[method] ?? 0,
          amountArs: arsByMethod[method] ?? 0,
          share: totalBase > 0 ? baseOf(method) / totalBase : 1.0 / order.length,
          // Delta vs lista en ARS: lo pagado (USD a ARS por tipo de cambio)
          // menos el precio de lista de esos productos.
          deltaArs: listaByMethod.containsKey(method)
              ? baseOf(method) - (listaByMethod[method] ?? 0)
              : 0,
        ),
    ];
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
