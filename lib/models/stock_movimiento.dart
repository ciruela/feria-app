enum StockMotivo {
  carga('carga', 'Carga'),
  venta('venta', 'Venta'),
  ajuste('ajuste', 'Ajuste'),
  anulacion('anulacion', 'Anulación');

  const StockMotivo(this.key, this.label);

  final String key;
  final String label;

  static StockMotivo fromKey(String? key) {
    return StockMotivo.values.firstWhere(
      (motivo) => motivo.key == key,
      orElse: () => StockMotivo.ajuste,
    );
  }
}

class StockMovimiento {
  const StockMovimiento({
    required this.id,
    required this.productoId,
    required this.delta,
    required this.motivo,
    required this.createdAt,
    this.stockAntes,
    this.stockDespues,
    this.ventaId,
    this.vendedorId,
    this.nota = '',
  });

  final String id;
  final String productoId;

  /// Variación en unidades vendibles (munición = cajas). +carga / −venta / ±ajuste.
  final int delta;
  final StockMotivo motivo;
  final DateTime createdAt;
  final int? stockAntes;
  final int? stockDespues;
  final String? ventaId;
  final String? vendedorId;
  final String nota;

  bool get isEntrada => delta > 0;
  bool get isSalida => delta < 0;

  factory StockMovimiento.fromRow(Map<String, dynamic> row) {
    return StockMovimiento(
      id: row['id'] as String,
      productoId: row['producto_id'] as String,
      delta: (row['delta'] as num).toInt(),
      motivo: StockMotivo.fromKey(row['motivo'] as String?),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      stockAntes: (row['stock_antes'] as num?)?.toInt(),
      stockDespues: (row['stock_despues'] as num?)?.toInt(),
      ventaId: row['venta_id'] as String?,
      vendedorId: row['vendedor_id'] as String?,
      nota: row['nota'] as String? ?? '',
    );
  }
}
