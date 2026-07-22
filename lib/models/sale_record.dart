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
  final List<SaleLineRecord> lines;

  double get collectedArs => lines
      .where((line) => !line.paysInUsd)
      .fold(0.0, (sum, line) => sum + line.lineArs);

  double get collectedUsd => lines
      .where((line) => line.paysInUsd)
      .fold(0.0, (sum, line) => sum + line.lineUsd);

  bool get hasPdf => pdfPath != null && pdfPath!.isNotEmpty;

  factory SaleRecord.fromRow(Map<String, dynamic> row) {
    final items = row['items'] as Map<String, dynamic>? ?? {};
    final rawLines = items['lines'] as List<dynamic>? ?? [];
    final sellerFromItems = items['sellerName'] as String?;

    return SaleRecord(
      id: row['id'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      sellerName: sellerFromItems,
      vendedorId: row['vendedor_id'] as String?,
      totalArs: (row['total_ars'] as num?)?.toDouble() ?? 0,
      totalUsd: (row['total_usd'] as num?)?.toDouble() ?? 0,
      clienteNombre: row['cliente_nombre'] as String? ?? '',
      clienteDni: row['cliente_dni'] as String? ?? '',
      pdfPath: row['pdf_path'] as String?,
      lines: rawLines
          .map((line) => SaleLineRecord.fromJson(line as Map<String, dynamic>))
          .toList(),
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
  });

  final String productId;
  final String? productType;
  final int quantity;
  final double lineArs;
  final double lineUsd;
  final String paymentMethod;
  final bool isArma;
  final int? splitPart;

  factory SaleLineRecord.fromJson(Map<String, dynamic> json) {
    return SaleLineRecord(
      productId: json['productId'] as String? ?? '',
      productType: json['productType'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      lineArs: (json['lineArs'] as num?)?.toDouble() ?? 0,
      lineUsd: (json['lineUsd'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String? ?? 'lista',
      isArma: json['isArma'] as bool? ?? false,
      splitPart: (json['splitPart'] as num?)?.toInt(),
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
