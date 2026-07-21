class ProductPrices {
  const ProductPrices({
    required this.usd,
    required this.lista,
    required this.efectivo,
    required this.tarjeta3,
    required this.tarjeta6,
    required this.tarjeta12,
  });

  final double usd;
  final double lista;
  final double efectivo;
  final double tarjeta3;
  final double tarjeta6;
  final double tarjeta12;

  double get cuota3 => tarjeta3 / 3;
  double get cuota6 => tarjeta6 / 6;
  double get cuota12 => tarjeta12 / 12;
}

enum PaymentMethod {
  dolarBillete('Dólar billete', 'dolar_billete'),
  transferencia('Transferencia', 'transferencia'),
  lista('Lista', 'lista'),
  efectivo('Efectivo', 'efectivo'),
  tarjeta3('Tarjeta 3 cuotas', 'tarjeta3'),
  tarjeta6('Tarjeta 6 cuotas', 'tarjeta6'),
  tarjeta12('Tarjeta 12 cuotas', 'tarjeta12');

  const PaymentMethod(this.label, this.key);

  final String label;
  final String key;

  bool get isUsdPayment => this == PaymentMethod.dolarBillete;

  /// Monto en pesos según la forma de pago elegida.
  double totalArsFor(ProductPrices prices) {
    return switch (this) {
      PaymentMethod.dolarBillete => prices.lista,
      PaymentMethod.transferencia => prices.lista,
      PaymentMethod.lista => prices.lista,
      PaymentMethod.efectivo => prices.efectivo,
      PaymentMethod.tarjeta3 => prices.tarjeta3,
      PaymentMethod.tarjeta6 => prices.tarjeta6,
      PaymentMethod.tarjeta12 => prices.tarjeta12,
    };
  }

  /// Monto en dólares del producto (siempre el precio catálogo).
  double totalUsdFor(ProductPrices prices) => prices.usd;
}

/// Formas de pago que se preguntan al agregar un arma al carrito.
const weaponPaymentMethods = [
  PaymentMethod.dolarBillete,
  PaymentMethod.transferencia,
  PaymentMethod.efectivo,
  PaymentMethod.lista,
  PaymentMethod.tarjeta3,
  PaymentMethod.tarjeta6,
  PaymentMethod.tarjeta12,
];
