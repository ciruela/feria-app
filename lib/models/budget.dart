import 'product.dart';
import 'product_prices.dart';
import 'cart_checkout_payment.dart';
import '../utils/formatters.dart';

class BudgetLine {
  const BudgetLine({
    required this.lineKey,
    required this.productId,
    required this.code,
    required this.quantity,
    required this.detail,
    required this.unitArs,
    required this.lineArs,
    required this.unitUsd,
    required this.lineUsd,
    required this.paymentMethod,
    required this.isArma,
    this.serialNumber = '',
    this.tarjetaConsumo = '',
    this.splitPart,
    this.productType = '',
    this.listaArs = 0,
  });

  final String lineKey;
  final String productId;
  final String code;
  final int quantity;
  final String detail;
  final double unitArs;
  final double lineArs;
  final double unitUsd;
  final double lineUsd;
  final PaymentMethod paymentMethod;
  final bool isArma;
  final String serialNumber;
  final String tarjetaConsumo;
  final int? splitPart;
  final String productType;

  /// Precio de lista de la línea en ARS (referencia para el delta "vs lista").
  final double listaArs;

  bool get isSplitPart => splitPart != null;

  String get paymentLabel => paymentMethod.label;

  bool get paysInUsd => paymentMethod.isUsdPayment;

  String get formattedUnit =>
      paysInUsd ? formatUsd(unitUsd) : formatArs(unitArs);

  String get formattedLine =>
      paysInUsd ? formatUsd(lineUsd) : formatArs(lineArs);

  String get formattedUnitPlain => paysInUsd
      ? formatUsd(unitUsd).replaceAll('USD ', '')
      : formatArs(unitArs).replaceAll(r'$ ', '');

  String get formattedLinePlain => paysInUsd
      ? formatUsd(lineUsd).replaceAll('USD ', '')
      : formatArs(lineArs).replaceAll(r'$ ', '');
}

class BudgetCustomer {
  const BudgetCustomer({
    this.fullName = '',
    this.dni = '',
    this.clu = '',
    this.cluExpiry = '',
    this.phone = '',
    this.email = '',
    this.fiscalCondition = '',
    this.address = '',
    this.city = '',
    this.notes = '',
  });

  final String fullName;
  final String dni;
  final String clu;
  final String cluExpiry;
  final String phone;
  final String email;

  /// Condición fiscal en recibo Urban (ej. Cons. final).
  final String fiscalCondition;
  final String address;
  final String city;
  final String notes;

  /// Domicilio para comprobantes que usan una sola línea (Urban).
  String get domicilioLine {
    final parts = [
      address.trim(),
      city.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(' · ');
  }

  /// AR-58: une calle + localidad en un solo `address` (campo único Urban).
  BudgetCustomer mergeDomicilioIntoAddress() {
    final cityTrim = city.trim();
    if (cityTrim.isEmpty) return this;
    final addressTrim = address.trim();
    final merged = addressTrim.isEmpty
        ? cityTrim
        : (addressTrim.toLowerCase().contains(cityTrim.toLowerCase())
            ? addressTrim
            : '$addressTrim · $cityTrim');
    return copyWith(address: merged, city: '');
  }

  BudgetCustomer copyWith({
    String? fullName,
    String? dni,
    String? clu,
    String? cluExpiry,
    String? phone,
    String? email,
    String? fiscalCondition,
    String? address,
    String? city,
    String? notes,
  }) {
    return BudgetCustomer(
      fullName: fullName ?? this.fullName,
      dni: dni ?? this.dni,
      clu: clu ?? this.clu,
      cluExpiry: cluExpiry ?? this.cluExpiry,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      fiscalCondition: fiscalCondition ?? this.fiscalCondition,
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
    );
  }

  bool get isEmpty =>
      fullName.isEmpty &&
      dni.isEmpty &&
      clu.isEmpty &&
      cluExpiry.isEmpty &&
      phone.isEmpty &&
      email.isEmpty &&
      address.isEmpty &&
      city.isEmpty &&
      notes.isEmpty;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'dni': dni,
        'clu': clu,
        'cluExpiry': cluExpiry,
        'phone': phone,
        'email': email,
        'fiscalCondition': fiscalCondition,
        'address': address,
        'city': city,
        'notes': notes,
      };

  factory BudgetCustomer.fromJson(Map<String, dynamic> json) {
    String read(String key) => json[key] as String? ?? '';
    return BudgetCustomer(
      fullName: read('fullName'),
      dni: read('dni'),
      clu: read('clu'),
      cluExpiry: read('cluExpiry'),
      phone: read('phone'),
      email: read('email'),
      fiscalCondition: read('fiscalCondition'),
      address: read('address'),
      city: read('city'),
      notes: read('notes'),
    );
  }
}

class Budget {
  const Budget({
    required this.date,
    required this.customer,
    required this.lines,
    required this.totalUsd,
    required this.totalArs,
    this.sellerName,
    this.paymentAllocations = const [],
  });

  final DateTime date;
  final BudgetCustomer customer;
  final String? sellerName;
  final List<BudgetLine> lines;
  final double totalUsd;
  final double totalArs;
  final List<PaymentAllocation> paymentAllocations;

  Set<PaymentMethod> get paymentMethods {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.map((allocation) => allocation.method).toSet();
    }
    return lines.map((line) => line.paymentMethod).toSet();
  }

  Budget copyWithCustomer(BudgetCustomer customer) {
    return Budget(
      date: date,
      customer: customer,
      lines: lines,
      totalUsd: totalUsd,
      totalArs: totalArs,
      sellerName: sellerName,
      paymentAllocations: paymentAllocations,
    );
  }

  bool get hasUsdPayments {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.any((allocation) => allocation.paysInUsd);
    }
    return lines.any((line) => line.paysInUsd);
  }

  bool get hasArsPayments {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.any((allocation) => !allocation.paysInUsd);
    }
    return lines.any((line) => !line.paysInUsd);
  }

  double get totalUsdLines {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.fold(
          0.0, (sum, allocation) => sum + allocation.amountUsd);
    }
    return lines
        .where((line) => line.paysInUsd)
        .fold(0.0, (sum, line) => sum + line.lineUsd);
  }

  double get totalArsLines {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.fold(
          0.0, (sum, allocation) => sum + allocation.amountArs);
    }
    return lines
        .where((line) => !line.paysInUsd)
        .fold(0.0, (sum, line) => sum + line.lineArs);
  }
}

extension ProductBudgetX on Product {
  /// Detalle completo (incluye descripción). World Guns / genérico.
  String budgetDetailFull() {
    if (isMunicion) {
      final desc = descripcion.trim();
      if (desc.isNotEmpty) return desc.toUpperCase();
      return budgetDetail();
    }

    final parts = <String>[
      marcaUpper,
      modeloDisplay,
      if (calibre.isNotEmpty) 'Cal. $calibre',
    ];
    final extra = descripcion.trim();
    if (extra.isNotEmpty) {
      final joined = parts.join(' · ').toUpperCase();
      if (!joined.contains(extra.toUpperCase())) {
        parts.add(extra.toUpperCase());
      }
    }
    return parts.join(' · ');
  }

  /// Marca · modelo · calibre (sin descripción larga). Urban Tactical.
  String budgetDetail() {
    if (isArma) {
      return [
        marcaUpper,
        modeloDisplay,
        if (calibre.trim().isNotEmpty) 'Cal. $calibre',
      ].where((part) => part.trim().isNotEmpty).join(' · ');
    }

    return [
      marcaUpper,
      if (codigo.trim().isNotEmpty) codigo,
      if (calibre.trim().isNotEmpty) 'Cal. $calibre',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
  }

  /// [compact] omite la descripción completa (recibo Urban).
  String budgetDetailForReceipt({required bool compact}) =>
      compact ? budgetDetail() : budgetDetailFull();

  String get budgetCode => codigo.isNotEmpty ? codigo : id;
}
