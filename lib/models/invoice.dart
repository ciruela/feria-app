import 'product.dart';
import 'product_prices.dart';

class InvoiceLine {
  const InvoiceLine({
    required this.productName,
    required this.internalCode,
    required this.productCode,
    required this.quantity,
    required this.paymentMethod,
    required this.lineUsd,
    required this.lineArs,
  });

  final String productName;
  final String internalCode;
  final String productCode;
  final int quantity;
  final PaymentMethod paymentMethod;
  final double lineUsd;
  final double lineArs;

  String get paymentLabel => paymentMethod.label;
}

class Invoice {
  const Invoice({
    required this.buyerFullName,
    required this.date,
    required this.lines,
    required this.totalUsd,
    required this.totalArs,
    this.sellerName,
  });

  final String buyerFullName;
  final DateTime date;
  final String? sellerName;
  final List<InvoiceLine> lines;
  final double totalUsd;
  final double totalArs;
}

extension ProductInvoiceX on Product {
  String get invoiceProductName {
    if (isArma) {
      return '$marca · $modeloDisplay';
    }
    return '$marca · $codigo';
  }
}
