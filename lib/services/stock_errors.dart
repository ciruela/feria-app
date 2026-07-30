/// Stock insuficiente al confirmar una venta.
class InsufficientStockException implements Exception {
  InsufficientStockException({
    required this.productId,
    required this.requested,
    required this.available,
    this.label = '',
  });

  final String productId;
  final int requested;
  final int available;
  final String label;

  @override
  String toString() {
    final name = label.isNotEmpty ? label : productId;
    return 'Stock insuficiente: $name (disponible $available, pedido $requested)';
  }
}

/// Producto sin stock cargado — no se puede vender con inventario activo.
class StockNotTrackedException implements Exception {
  StockNotTrackedException({required this.productId, this.label = ''});

  final String productId;
  final String label;

  @override
  String toString() {
    final name = label.isNotEmpty ? label : productId;
    return 'Sin stock cargado: $name. Completá el stock en administración.';
  }
}

/// Otro dispositivo modificó el stock antes de confirmar (reintentá).
class StockConflictException implements Exception {
  StockConflictException({required this.productId, this.label = ''});

  final String productId;
  final String label;

  @override
  String toString() {
    final name = label.isNotEmpty ? label : productId;
    return 'El stock de $name cambió recién. Actualizá y volvé a intentar.';
  }
}
