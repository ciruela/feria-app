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
    this.splitPart,
    this.productType = '',
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
  final int? splitPart;
  final String productType;

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
  final String address;
  final String city;
  final String notes;

  BudgetCustomer copyWith({
    String? fullName,
    String? dni,
    String? clu,
    String? cluExpiry,
    String? phone,
    String? email,
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
      address: address ?? this.address,
      city: city ?? this.city,
      notes: notes ?? this.notes,
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
      return paymentAllocations.fold(0.0, (sum, allocation) => sum + allocation.amountUsd);
    }
    return lines
        .where((line) => line.paysInUsd)
        .fold(0.0, (sum, line) => sum + line.lineUsd);
  }

  double get totalArsLines {
    if (paymentAllocations.isNotEmpty) {
      return paymentAllocations.fold(0.0, (sum, allocation) => sum + allocation.amountArs);
    }
    return lines
        .where((line) => !line.paysInUsd)
        .fold(0.0, (sum, line) => sum + line.lineArs);
  }
}

extension ProductBudgetX on Product {
  String budgetDetail() {
    if (isArma) {
      return [
        marcaUpper,
        modeloDisplay,
        'Cal. $calibre',
      ].join(' · ');
    }

    return '$marcaUpper · $codigo · Cal. $calibre';
  }

  String get budgetCode =>
      codigo.isNotEmpty ? codigo : id;
}
