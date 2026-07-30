import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/stock_movimiento.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import 'product_photo_service.dart';
import 'stock_errors.dart';
import 'supabase_service.dart';
import 'supabase_stock_movimientos_repository.dart';

class SupabaseCatalogRepository {
  static const _table = 'productos';
  static const _rpcApplyDelta = 'apply_product_stock_delta';

  final SupabaseStockMovimientosRepository _movimientos =
      SupabaseStockMovimientosRepository();

  Future<List<Product>> fetchAll() async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .order('marca')
        .order('codigo');

    return (rows as List<dynamic>)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsert(Product product) async {
    await SupabaseService.client.from(_table).upsert(_toRow(product));
  }

  Future<void> upsertAll(List<Product> products) async {
    if (products.isEmpty) return;

    await SupabaseService.client
        .from(_table)
        .upsert(products.map(_toRow).toList());
  }

  Future<void> delete(String productId) async {
    await SupabaseService.client.from(_table).delete().eq('id', productId);
  }

  Product productFromRow(Map<String, dynamic> row) => _fromRow(row);

  /// Descuenta stock en Supabase. Retorna el saldo nuevo o lanza si no alcanza.
  Future<int> decrementStock(
    String productId,
    int quantity, {
    String? ventaId,
    String? vendedorId,
    String label = '',
  }) async {
    if (quantity <= 0) {
      return _readStockOrThrow(productId, label: label);
    }

    return _applyDelta(
      productId: productId,
      delta: -quantity,
      motivo: StockMotivo.venta,
      ventaId: ventaId,
      vendedorId: vendedorId,
      label: label,
    );
  }

  /// Restituye stock al anular una venta.
  Future<int> restoreStock(
    String productId,
    int quantity, {
    String? ventaId,
    String? vendedorId,
    String label = '',
  }) async {
    if (quantity <= 0) {
      return _readStockOrThrow(productId, label: label);
    }

    return _applyDelta(
      productId: productId,
      delta: quantity,
      motivo: StockMotivo.anulacion,
      ventaId: ventaId,
      vendedorId: vendedorId,
      label: label,
    );
  }

  Future<int> _applyDelta({
    required String productId,
    required int delta,
    required StockMotivo motivo,
    String? ventaId,
    String? vendedorId,
    String label = '',
  }) async {
    try {
      final result = await SupabaseService.client.rpc<int>(
        _rpcApplyDelta,
        params: {
          'p_product_id': productId,
          'p_delta': delta,
          'p_motivo': motivo.key,
          'p_venta_id': ventaId,
          'p_vendedor_id': vendedorId,
        },
      );
      return result;
    } on PostgrestException catch (error) {
      if (!_isRpcMissing(error)) {
        _throwStockError(error, productId: productId, label: label, delta: delta);
      }
    } catch (error) {
      if (error is InsufficientStockException ||
          error is StockNotTrackedException ||
          error is StockConflictException) {
        rethrow;
      }
      AppLogger.warn(
        'RPC apply_product_stock_delta no disponible, usando fallback',
        error: error,
      );
    }

    return _applyDeltaFallback(
      productId: productId,
      delta: delta,
      motivo: motivo,
      ventaId: ventaId,
      vendedorId: vendedorId,
      label: label,
    );
  }

  bool _isRpcMissing(PostgrestException error) {
    final msg = error.message.toLowerCase();
    return msg.contains('apply_product_stock_delta') &&
        (msg.contains('does not exist') || msg.contains('could not find'));
  }

  void _throwStockError(
    PostgrestException error, {
    required String productId,
    required String label,
    required int delta,
  }) {
    final msg = error.message.toLowerCase();
    if (msg.contains('insufficient_stock')) {
      throw InsufficientStockException(
        productId: productId,
        requested: delta.abs(),
        available: 0,
        label: label,
      );
    }
    if (msg.contains('stock_not_tracked')) {
      throw StockNotTrackedException(productId: productId, label: label);
    }
    if (msg.contains('product_not_found')) {
      throw StateError('Producto no encontrado: ${label.isNotEmpty ? label : productId}');
    }
    throw StateError('No se pudo actualizar stock: ${error.message}');
  }

  Future<int> _applyDeltaFallback({
    required String productId,
    required int delta,
    required StockMotivo motivo,
    String? ventaId,
    String? vendedorId,
    String label = '',
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final row = await SupabaseService.client
          .from(_table)
          .select('stock')
          .eq('id', productId)
          .maybeSingle();

      if (row == null) {
        throw StateError('Producto no encontrado: ${label.isNotEmpty ? label : productId}');
      }

      final current = row['stock'] as int?;
      if (current == null) {
        throw StockNotTrackedException(productId: productId, label: label);
      }

      final next = current + delta;
      if (next < 0) {
        throw InsufficientStockException(
          productId: productId,
          requested: delta.abs(),
          available: current,
          label: label,
        );
      }

      final updated = await SupabaseService.client
          .from(_table)
          .update({
            'stock': next,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', productId)
          .eq('stock', current)
          .select('stock')
          .maybeSingle();

      if (updated == null) {
        if (attempt == 1) {
          throw StockConflictException(productId: productId, label: label);
        }
        continue;
      }

      await _insertMovementWithRetry(
        productoId: productId,
        delta: delta,
        motivo: motivo,
        stockAntes: current,
        stockDespues: next,
        ventaId: ventaId,
        vendedorId: vendedorId,
      );

      return next;
    }

    throw StockConflictException(productId: productId, label: label);
  }

  Future<int> _readStockOrThrow(String productId, {String label = ''}) async {
    final row = await SupabaseService.client
        .from(_table)
        .select('stock')
        .eq('id', productId)
        .maybeSingle();
    if (row == null) {
      throw StateError('Producto no encontrado: ${label.isNotEmpty ? label : productId}');
    }
    final current = row['stock'] as int?;
    if (current == null) {
      throw StockNotTrackedException(productId: productId, label: label);
    }
    return current;
  }

  Future<void> _insertMovementWithRetry({
    required String productoId,
    required int delta,
    required StockMotivo motivo,
    int? stockAntes,
    int? stockDespues,
    String? ventaId,
    String? vendedorId,
    String nota = '',
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        await _movimientos.insert(
          productoId: productoId,
          delta: delta,
          motivo: motivo,
          stockAntes: stockAntes,
          stockDespues: stockDespues,
          ventaId: ventaId,
          vendedorId: vendedorId,
          nota: nota,
        );
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
      }
    }
    AppLogger.error(
      'Stock actualizado pero falló el movimiento de auditoría',
      error: lastError,
      stackTrace: lastStack,
    );
  }

  /// Registra carga/ajuste manual de stock (auditoría). No modifica el stock:
  /// el stock se persiste con el upsert del producto.
  Future<void> logStockChange({
    required String productId,
    required int delta,
    required StockMotivo motivo,
    int? stockAntes,
    int? stockDespues,
    String nota = '',
  }) async {
    if (delta == 0) return;
    await _insertMovementWithRetry(
      productoId: productId,
      delta: delta,
      motivo: motivo,
      stockAntes: stockAntes,
      stockDespues: stockDespues,
      nota: nota,
    );
  }

  Product _fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      type: ProductType.fromKey(row['type'] as String),
      marca: row['marca'] as String,
      calibre: row['calibre'] as String,
      codigo: row['codigo'] as String? ?? '',
      modelo: row['modelo'] as String? ?? '',
      descripcion: row['descripcion'] as String? ?? '',
      precioUsd: (row['precio_usd'] as num).toDouble(),
      foto: row['foto'] as String? ?? '',
      fotoUrls: ProductPhotoService.parsePathsFromRow(row),
      stock: row['stock'] as int?,
      stockInicial: row['stock_inicial'] as int?,
      roundsPerBox: row['rounds_per_box'] as int?,
    );
  }

  Map<String, dynamic> _toRow(Product product) {
    final paths = ProductPhotoService.pathsForStorage(product);
    final row = <String, dynamic>{
      'id': product.id,
      'type': product.type.key,
      'marca': product.marca,
      'calibre': product.calibre,
      'codigo': product.codigo,
      'modelo': product.modelo,
      'descripcion': product.descripcion,
      'precio_usd': product.precioUsd,
      'foto': product.foto,
      'foto_url': paths.isNotEmpty ? paths.first : '',
      'fotos': paths,
      'stock': product.stock,
      'stock_inicial': product.stockInicial,
      'rounds_per_box': product.roundsPerBox,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final tenantId = _tenantIdFromJwt();
    if (tenantId != null) {
      row['tenant_id'] = tenantId;
    }
    return row;
  }

  String? _tenantIdFromJwt() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final id = (decodeJwtPayload(session.accessToken)['tenant_id'] as String?)
        ?.trim();
    return id != null && id.isNotEmpty ? id : null;
  }
}
