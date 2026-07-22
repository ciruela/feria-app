import 'product_prices.dart';

/// Forma de pago acordada para toda la venta (carrito / comprobante).
class CartCheckoutPayment {
  const CartCheckoutPayment({
    required this.pricingMethod,
    this.secondMethod,
    this.primaryShare = 1.0,
  });

  const CartCheckoutPayment.single(PaymentMethod method)
      : pricingMethod = method,
        secondMethod = null,
        primaryShare = 1.0;

  const CartCheckoutPayment.dual({
    required PaymentMethod pricingMethod,
    required PaymentMethod secondMethod,
    required double primaryShare,
  })  : pricingMethod = pricingMethod,
        secondMethod = secondMethod,
        primaryShare = primaryShare;

  /// Método que define el precio de cada ítem en el comprobante.
  final PaymentMethod pricingMethod;

  /// Segunda forma de cobro (opcional).
  final PaymentMethod? secondMethod;

  /// Porción cobrada con [pricingMethod] cuando hay pago doble (0.05–0.95).
  final double primaryShare;

  bool get isDual => secondMethod != null;

  double get secondaryShare => 1.0 - primaryShare;

  PaymentMethod? get secondaryMethod => secondMethod;
}

class PaymentAllocation {
  const PaymentAllocation({
    required this.method,
    required this.amountUsd,
    required this.amountArs,
  });

  final PaymentMethod method;
  final double amountUsd;
  final double amountArs;

  bool get paysInUsd => method.isUsdPayment;
}
