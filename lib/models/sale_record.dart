import 'budget.dart';
import 'product_prices.dart';

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.createdAt,
    required this.lines,
    this.sellerName,
    this.vendedorId,
    this.totalArs = 0,
    this.totalUsd = 0,
    this.clienteNombre = '',
    this.clienteDni = '',
    this.pdfPath,
    this.anulada = false,
    this.anuladaMotivo = '',
    this.anuladaPor = '',
    this.anuladaAt,
    this.customerDetail = const BudgetCustomer(),
    this.saleDate,
  });

  final String id;
  final DateTime createdAt;
  final String? sellerName;
  final String? vendedorId;
  final double totalArs;
  final double totalUsd;
  final String clienteNombre;
  final String clienteDni;
  final String? pdfPath;
  final bool anulada;
  final String anuladaMotivo;
  final String anuladaPor;
  final DateTime? anuladaAt;
  final List<SaleLineRecord> lines;
  final BudgetCustomer customerDetail;
  final DateTime? saleDate;

  double get collectedArs => lines
      .where((line) => !line.paysInUsd)
      .fold(0.0, (sum, line) => sum + line.lineArs);

  double get collectedUsd => lines
      .where((line) => line.paysInUsd)
      .fold(0.0, (sum, line) => sum + line.lineUsd);

  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;

  /// Reconstruye el presupuesto/comprobante a partir de lo guardado en la venta.
  Budget toBudget() {
    final customer = customerDetail.fullName.trim().isNotEmpty
        ? customerDetail
        : BudgetCustomer(
            fullName: clienteNombre,
            dni: clienteDni,
          );

    return Budget(
      date: saleDate ?? createdAt,
      customer: customer,
      sellerName: sellerName,
      lines: [
        for (var i = 0; i < lines.length; i++)
          lines[i].toBudgetLine(index: i),
      ],
      totalUsd: totalUsd,
      totalArs: totalArs,
    );
  }

  factory SaleRecord.fromRow(Map<String, dynamic> row) {
    final items = row['items'] as Map<String, dynamic>? ?? {};
    final rawLines = items['lines'] as List<dynamic>? ?? [];
    final sellerFromItems = items['sellerName'] as String?;
    final createdAt =
        DateTime.parse(row['created_at'] as String).toLocal();
    final rawSaleDate = items['date'] as String?;

    return SaleRecord(
      id: row['id'] as String,
      createdAt: createdAt,
      sellerName: sellerFromItems,
      vendedorId: row['vendedor_id'] as String?,
      totalArs: (row['total_ars'] as num?)?.toDouble() ?? 0,
      totalUsd: (row['total_usd'] as num?)?.toDouble() ?? 0,
      clienteNombre: row['cliente_nombre'] as String? ?? '',
      clienteDni: row['cliente_dni'] as String? ?? '',
      pdfPath: row['pdf_path'] as String?,
      anulada: row['anulada'] as bool? ?? false,
      anuladaMotivo: row['anulada_motivo'] as String? ?? '',
      anuladaPor: row['anulada_por'] as String? ?? '',
      anuladaAt: row['anulada_at'] == null
          ? null
          : DateTime.parse(row['anulada_at'] as String).toLocal(),
      customerDetail: _parseCustomer(items['customer'] as Map<String, dynamic>?),
      saleDate: rawSaleDate == null
          ? null
          : DateTime.parse(rawSaleDate).toLocal(),
      lines: rawLines
          .map((line) => SaleLineRecord.fromJson(line as Map<String, dynamic>))
          .toList(),
    );
  }

  static BudgetCustomer _parseCustomer(Map<String, dynamic>? raw) {
    if (raw == null) return const BudgetCustomer();
    return BudgetCustomer(
      fullName: raw['fullName'] as String? ?? '',
      dni: raw['dni'] as String? ?? '',
      clu: raw['clu'] as String? ?? '',
      cluExpiry: raw['cluExpiry'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      address: raw['address'] as String? ?? '',
      city: raw['city'] as String? ?? '',
      notes: raw['notes'] as String? ?? '',
    );
  }
}

class SaleLineRecord {
  const SaleLineRecord({
    required this.productId,
    required this.quantity,
    required this.lineArs,
    required this.lineUsd,
    required this.paymentMethod,
    required this.isArma,
    this.productType,
    this.splitPart,
    this.detail = '',
    this.code = '',
    this.unitArs = 0,
    this.unitUsd = 0,
    this.serialNumber = '',
  });

  final String productId;
  final String? productType;
  final int quantity;
  final double lineArs;
  final double lineUsd;
  final String paymentMethod;
  final bool isArma;
  final int? splitPart;
  final String detail;
  final String code;
  final double unitArs;
  final double unitUsd;
  final String serialNumber;

  factory SaleLineRecord.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final lineArs = (json['lineArs'] as num?)?.toDouble() ?? 0;
    final lineUsd = (json['lineUsd'] as num?)?.toDouble() ?? 0;
    var unitArs = (json['unitArs'] as num?)?.toDouble() ?? 0;
    var unitUsd = (json['unitUsd'] as num?)?.toDouble() ?? 0;
    if (unitArs <= 0 && lineArs > 0 && quantity > 0) {
      unitArs = lineArs / quantity;
    }
    if (unitUsd <= 0 && lineUsd > 0 && quantity > 0) {
      unitUsd = lineUsd / quantity;
    }

    return SaleLineRecord(
      productId: json['productId'] as String? ?? '',
      productType: json['productType'] as String?,
      quantity: quantity,
      lineArs: lineArs,
      lineUsd: lineUsd,
      paymentMethod: json['paymentMethod'] as String? ?? 'lista',
      isArma: json['isArma'] as bool? ?? false,
      splitPart: (json['splitPart'] as num?)?.toInt(),
      detail: json['detail'] as String? ?? '',
      code: json['code'] as String? ?? '',
      unitArs: unitArs,
      unitUsd: unitUsd,
      serialNumber: json['serialNumber'] as String? ?? '',
    );
  }

  BudgetLine toBudgetLine({required int index}) {
    final method = PaymentMethod.fromKey(paymentMethod);
    final key = splitPart == null
        ? '$productId-$index'
        : '$productId-split$splitPart';

    return BudgetLine(
      lineKey: key,
      productId: productId,
      code: code,
      quantity: quantity,
      detail: detail,
      unitArs: unitArs,
      lineArs: lineArs,
      unitUsd: unitUsd,
      lineUsd: lineUsd,
      paymentMethod: method,
      isArma: isArma,
      serialNumber: serialNumber,
      splitPart: splitPart,
      productType: resolvedProductType,
    );
  }

  bool get isSplitSecondPart => splitPart == 2;

  String get resolvedProductType {
    if (productType != null && productType!.isNotEmpty) return productType!;

    if (productId.startsWith('municion')) return 'municion';
    if (productId.startsWith('arma_corta')) return 'arma_corta';
    if (productId.startsWith('arma_larga')) return 'arma_larga';
    return isArma ? 'arma_corta' : 'municion';
  }

  bool get paysInUsd => paymentMethod == 'dolar_billete';
}
