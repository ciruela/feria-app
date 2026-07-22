class ProductPrices {
  const ProductPrices({
    required this.usd,
    required this.lista,
    required this.efectivo,
    required this.debito,
    required this.tarjeta1,
    required this.tarjeta3,
    required this.tarjeta6,
    required this.tarjeta9,
    required this.tarjeta12,
    required this.tarjeta18,
  });

  final double usd;
  final double lista;
  final double efectivo;
  final double debito;
  final double tarjeta1;
  final double tarjeta3;
  final double tarjeta6;
  final double tarjeta9;
  final double tarjeta12;
  final double tarjeta18;

  double get cuota1 => tarjeta1;
  double get cuota3 => tarjeta3 / 3;
  double get cuota6 => tarjeta6 / 6;
  double get cuota9 => tarjeta9 / 9;
  double get cuota12 => tarjeta12 / 12;
  double get cuota18 => tarjeta18 / 18;
}

enum PaymentMethod {
  dolarBillete('Dólar billete', 'dolar_billete'),
  transferencia('Transferencia', 'transferencia'),
  lista('Lista', 'lista'),
  efectivo('Efectivo', 'efectivo'),
  debito('Débito', 'debito'),
  tarjeta1('Tarjeta 1 cuota', 'tarjeta1'),
  tarjeta3('Tarjeta 3 cuotas', 'tarjeta3'),
  tarjeta6('Tarjeta 6 cuotas', 'tarjeta6'),
  tarjeta9('Tarjeta 9 cuotas', 'tarjeta9'),
  tarjeta12('Tarjeta 12 cuotas', 'tarjeta12'),
  tarjeta18('Tarjeta 18 cuotas', 'tarjeta18');

  const PaymentMethod(this.label, this.key);

  final String label;
  final String key;

  bool get isUsdPayment => this == PaymentMethod.dolarBillete;

  /// Etiqueta corta para diálogos y chips.
  String get shortLabel => switch (this) {
        PaymentMethod.dolarBillete => 'Dólar billete',
        PaymentMethod.transferencia => 'Transferencia',
        PaymentMethod.efectivo => 'Efectivo',
        PaymentMethod.lista => 'Lista',
        PaymentMethod.debito => 'Débito',
        PaymentMethod.tarjeta1 => '1 cuota',
        PaymentMethod.tarjeta3 => '3 cuotas',
        PaymentMethod.tarjeta6 => '6 cuotas',
        PaymentMethod.tarjeta9 => '9 cuotas',
        PaymentMethod.tarjeta12 => '12 cuotas',
        PaymentMethod.tarjeta18 => '18 cuotas',
      };

  /// Monto en pesos según la forma de pago elegida.
  double totalArsFor(ProductPrices prices) {
    return switch (this) {
      PaymentMethod.dolarBillete => prices.lista,
      PaymentMethod.transferencia => prices.lista,
      PaymentMethod.lista => prices.lista,
      PaymentMethod.efectivo => prices.efectivo,
      PaymentMethod.debito => prices.debito,
      PaymentMethod.tarjeta1 => prices.tarjeta1,
      PaymentMethod.tarjeta3 => prices.tarjeta3,
      PaymentMethod.tarjeta6 => prices.tarjeta6,
      PaymentMethod.tarjeta9 => prices.tarjeta9,
      PaymentMethod.tarjeta12 => prices.tarjeta12,
      PaymentMethod.tarjeta18 => prices.tarjeta18,
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
  PaymentMethod.debito,
  PaymentMethod.tarjeta1,
  PaymentMethod.tarjeta3,
  PaymentMethod.tarjeta6,
  PaymentMethod.tarjeta9,
  PaymentMethod.tarjeta12,
  PaymentMethod.tarjeta18,
];

/// Formas de pago seleccionables en diálogos (sin "lista", que es solo referencia de precio).
const selectablePaymentMethods = weaponPaymentMethods;

/// @deprecated Usar [selectablePaymentMethods]. Se mantiene por compatibilidad interna.
const allPaymentMethods = selectablePaymentMethods;
