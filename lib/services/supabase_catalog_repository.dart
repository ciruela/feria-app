import '../models/product.dart';
import '../models/stock_movimiento.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import 'product_photo_service.dart';
import 'supabase_service.dart';
import 'supabase_stock_movimientos_repository.dart';

class SupabaseCatalogRepository {
  static const _table = 'productos';

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

  Future<void> decrementStock(
    String productId,
    int quantity, {
    String? ventaId,
    String? vendedorId,
  }) async {
    if (quantity <= 0) return;

    final row = await SupabaseService.client
        .from(_table)
        .select('stock')
        .eq('id', productId)
        .maybeSingle();

    if (row == null) return;

    final current = row['stock'] as int?;
    if (current == null) return;

    final next = (current - quantity).clamp(0, current);

    await SupabaseService.client.from(_table).update({
      'stock': next,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);

    try {
      await _movimientos.insert(
        productoId: productId,
        delta: next - current,
        motivo: StockMotivo.venta,
        stockAntes: current,
        stockDespues: next,
        ventaId: ventaId,
        vendedorId: vendedorId,
      );
    } catch (e, s) {
      // El movimiento es auditoría: no bloquea la venta si falla.
      AppLogger.warn('No se registró el movimiento de stock (venta)',
          error: e, stackTrace: s);
    }
  }

  /// Restituye stock al anular una venta. Vuelve a sumar las unidades y deja
  /// un movimiento de auditoría con motivo "anulacion".
  Future<void> restoreStock(
    String productId,
    int quantity, {
    String? ventaId,
    String? vendedorId,
  }) async {
    if (quantity <= 0) return;

    final row = await SupabaseService.client
        .from(_table)
        .select('stock')
        .eq('id', productId)
        .maybeSingle();

    if (row == null) return;

    final current = row['stock'] as int?;
    if (current == null) return;

    final next = current + quantity;

    await SupabaseService.client.from(_table).update({
      'stock': next,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);

    try {
      await _movimientos.insert(
        productoId: productId,
        delta: next - current,
        motivo: StockMotivo.anulacion,
        stockAntes: current,
        stockDespues: next,
        ventaId: ventaId,
        vendedorId: vendedorId,
      );
    } catch (e, s) {
      AppLogger.warn('No se registró el movimiento de stock (anulación)',
          error: e, stackTrace: s);
    }
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
    try {
      await _movimientos.insert(
        productoId: productId,
        delta: delta,
        motivo: motivo,
        stockAntes: stockAntes,
        stockDespues: stockDespues,
        nota: nota,
      );
    } catch (e, s) {
      AppLogger.warn('No se registró el ajuste manual de stock',
          error: e, stackTrace: s);
    }
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
