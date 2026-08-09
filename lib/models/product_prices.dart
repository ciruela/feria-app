/// Precios cargados **tal cual** desde el Excel de un tenant (ej. Urban Tactical).
///
/// A diferencia del resto del catálogo, la app NO recalcula nada con estos
/// montos: los muestra fielmente. Todo en ARS salvo [efectivoUsd], que es la
/// referencia en dólares de las armas cotizadas en USD (Gral/Taurus).
class FixedPrices {
  const FixedPrices({
    this.efectivoArs,
    this.efectivoUsd,
    this.tarjetaArs,
    this.cuota3Ars,
    this.cuota6Ars,
    this.cuota12Ars,
  });

  /// Precio efectivo / transferencia (mismo valor en el Excel de Urban).
  final double? efectivoArs;

  /// Referencia en USD (armas Gral/Taurus). null cuando el Excel es solo ARS.
  final double? efectivoUsd;

  /// PVP con tarjeta en 1 pago.
  final double? tarjetaArs;

  /// Valor de CADA cuota (no el total) en 3/6/12 cuotas.
  final double? cuota3Ars;
  final double? cuota6Ars;
  final double? cuota12Ars;

  double? get tarjeta3Total => cuota3Ars == null ? null : cuota3Ars! * 3;
  double? get tarjeta6Total => cuota6Ars == null ? null : cuota6Ars! * 6;
  double? get tarjeta12Total => cuota12Ars == null ? null : cuota12Ars! * 12;

  bool get isEmpty =>
      (efectivoArs ?? 0) <= 0 &&
      (tarjetaArs ?? 0) <= 0 &&
      (cuota3Ars ?? 0) <= 0 &&
      (cuota6Ars ?? 0) <= 0 &&
      (cuota12Ars ?? 0) <= 0;

  Map<String, dynamic> toJson() => {
        if (efectivoArs != null) 'efectivo_ars': efectivoArs,
        if (efectivoUsd != null) 'efectivo_usd': efectivoUsd,
        if (tarjetaArs != null) 'tarjeta_ars': tarjetaArs,
        if (cuota3Ars != null) 'cuota3_ars': cuota3Ars,
        if (cuota6Ars != null) 'cuota6_ars': cuota6Ars,
        if (cuota12Ars != null) 'cuota12_ars': cuota12Ars,
      };

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString().trim());
    return parsed;
  }

  /// Reconstruye desde JSON (Supabase jsonb o caché local). Devuelve null si
  /// no hay ningún monto útil (así el resto del catálogo sigue el cálculo normal).
  static FixedPrices? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final fp = FixedPrices(
      efectivoArs: _num(json['efectivo_ars']),
      efectivoUsd: _num(json['efectivo_usd']),
      tarjetaArs: _num(json['tarjeta_ars']),
      cuota3Ars: _num(json['cuota3_ars']),
      cuota6Ars: _num(json['cuota6_ars']),
      cuota12Ars: _num(json['cuota12_ars']),
    );
    return fp.isEmpty ? null : fp;
  }
}

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
    double? transferencia,
  }) : transferencia = transferencia ?? lista;

  final double usd;
  final double lista;
  final double efectivo;

  /// Transferencia: por defecto = lista; en promos (p. ej. munición WG) = efectivo.
  final double transferencia;
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

  /// % de descuento efectivo vs lista (para labels de catálogo). 0 si no aplica.
  int get efectivoDescuentoPct {
    if (lista <= 0 || efectivo >= lista) return 0;
    return ((1 - efectivo / lista) * 100).round();
  }

  /// True cuando transferencia cotiza igual que efectivo (promo WG munición).
  bool get transferenciaConDescuentoEfectivo =>
      transferencia == efectivo && efectivo < lista;
}

enum PaymentMethod {
  dolarBillete('USD', 'dolar_billete'),
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
        PaymentMethod.dolarBillete => 'USD',
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
  ///
  /// USD / dólar billete cotiza como efectivo (mismo descuento).
  double totalArsFor(ProductPrices prices) {
    return switch (this) {
      PaymentMethod.dolarBillete => prices.efectivo,
      PaymentMethod.transferencia => prices.transferencia,
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

  /// Monto en dólares. USD billete aplica el mismo % que efectivo.
  double totalUsdFor(ProductPrices prices) {
    if (this == PaymentMethod.dolarBillete && prices.lista > 0) {
      return prices.usd * (prices.efectivo / prices.lista);
    }
    return prices.usd;
  }

  static PaymentMethod fromKey(String key) {
    for (final method in PaymentMethod.values) {
      if (method.key == key) return method;
    }
    return PaymentMethod.lista;
  }
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

/// Formas de pago del diálogo de checkout (mock 06_Desk — sin dólar billete).
const checkoutDialogPaymentMethods = [
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

/// Checkout: USD (`dolar_billete`) cuando el tenant lo habilita (WG / Urban).
///
/// Quien llama debe pasar [includeUsd] solo si el carrito tiene precio USD
/// usable en todos los ítems (ver [CartTotalsService.cartSupportsUsdCheckout]).
List<PaymentMethod> checkoutPaymentMethods({required bool includeUsd}) {
  if (!includeUsd) return checkoutDialogPaymentMethods;
  return [
    PaymentMethod.dolarBillete,
    ...checkoutDialogPaymentMethods,
  ];
}

/// Formas de pago seleccionables en diálogos (sin "lista", que es solo referencia de precio).
const selectablePaymentMethods = weaponPaymentMethods;

/// @deprecated Usar [selectablePaymentMethods]. Se mantiene por compatibilidad interna.
const allPaymentMethods = selectablePaymentMethods;
