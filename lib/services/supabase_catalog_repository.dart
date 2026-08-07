import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/product_prices.dart';
import '../models/stock_movimiento.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import '../utils/retry.dart';
import 'product_photo_service.dart';
import 'stock_errors.dart';
import 'supabase_service.dart';

class SupabaseCatalogRepository {
  static const _table = 'productos';
  static const _rpcApplyDelta = 'apply_product_stock_delta';
  static const _rpcSetStock = 'set_product_stock';

  /// Catálogo del tenant activo.
  ///
  /// IMPORTANTE: filtramos por [tenantId] en la consulta y NO confiamos solo en
  /// el RLS. Un platform admin pasa el RLS de `productos_select` para TODOS los
  /// tenants, así que sin este filtro un import cargaría en memoria productos de
  /// otras armerías y el matcher por código los pisaría (fuga entre tenants).
  Future<List<Product>> fetchAll({String? tenantId}) async {
    var query = SupabaseService.client.from(_table).select().eq('activo', true);
    if (tenantId != null && tenantId.isNotEmpty) {
      query = query.eq('tenant_id', tenantId);
    }
    final rows = await query.order('marca').order('codigo');

    return (rows as List<dynamic>)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// AR-35: soft-deleted rows still own `(tenant_id, codigo)`. Look them up
  /// so import/alta can restore the same id instead of inserting a conflict.
  Future<Product?> fetchByCodigoIncludingInactive(String codigo) async {
    final trimmed = codigo.trim();
    if (trimmed.isEmpty) return null;

    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .ilike('codigo', trimmed)
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return _fromRow(list.first as Map<String, dynamic>);
  }

  /// Stock actual en servidor para los ids dados (AR-6: no usar caché local).
  Future<Map<String, int?>> fetchStocksByIds(Iterable<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};

    final result = <String, int?>{};
    const chunkSize = 100;
    for (var i = 0; i < unique.length; i += chunkSize) {
      final chunk = unique.sublist(
        i,
        i + chunkSize > unique.length ? unique.length : i + chunkSize,
      );
      final rows = await SupabaseService.client
          .from(_table)
          .select('id, stock')
          .inFilter('id', chunk);
      for (final row in rows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        result[map['id'] as String] = map['stock'] as int?;
      }
    }
    return result;
  }

  /// Upsert de ficha de producto **sin** tocar `stock` (AR-6).
  ///
  /// No usamos `.upsert()` de PostgREST: con grants por columna (036), el
  /// ON CONFLICT intenta UPDATE de `tenant_id`/`id` y revienta con 42501
  /// ("permission denied for table productos") — típico al subir fotos.
  ///
  /// Returns the id actually written. If [product.id] is unknown but an
  /// inactive row shares the same `codigo`, that row is restored (AR-35).
  Future<String> upsert(
    Product product, {
    bool updatePhotos = true,
  }) async {
    final payload = _toUpdateRow(product, includePhotos: updatePhotos);

    final updated = await SupabaseService.client
        .from(_table)
        .update(payload)
        .eq('id', product.id)
        .select('id');

    if ((updated as List).isNotEmpty) {
      return product.id;
    }

    // Soft-deleted product still holds the unique codigo — reactivate it.
    final existing = await fetchByCodigoIncludingInactive(product.codigo);
    if (existing != null) {
      await SupabaseService.client
          .from(_table)
          .update(payload)
          .eq('id', existing.id)
          .select('id');
      return existing.id;
    }

    // Alta real: las fotos van (vacías al venir de Excel; con paths si es create UI).
    await SupabaseService.client.from(_table).insert(_toInsertRow(product));
    return product.id;
  }

  /// Upserts all products. Returns a map of requested id → persisted id when
  /// a soft-deleted row was restored under a different id (AR-35).
  Future<Map<String, String>> upsertAll(
    List<Product> products, {
    bool updatePhotos = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final remapped = <String, String>{};
    if (products.isEmpty) return remapped;
    var done = 0;
    onProgress?.call(0, products.length);
    for (final product in products) {
      final persistedId = await upsert(product, updatePhotos: updatePhotos);
      if (persistedId != product.id) {
        remapped[product.id] = persistedId;
      }
      done++;
      onProgress?.call(done, products.length);
    }
    return remapped;
  }

  /// Borrado lógico (AR-23): un producto con historial de stock no se puede
  /// borrar físicamente (FK on delete restrict); se marca inactivo para
  /// preservar la trazabilidad de sus movimientos.
  Future<void> delete(String productId) async {
    await SupabaseService.client
        .from(_table)
        .update({'activo': false})
        .eq('id', productId);
  }

  Product productFromRow(Map<String, dynamic> row) => _fromRow(row);

  /// Setea stock absoluto en servidor y deja movimiento (RPC).
  Future<int> setStock(
    String productId,
    int stock, {
    required StockMotivo motivo,
    String nota = '',
    String label = '',
  }) async {
    try {
      final result = await withTimeoutRetry(
        () => SupabaseService.client.rpc<int>(
          _rpcSetStock,
          params: {
            'p_product_id': productId,
            'p_stock': stock,
            'p_motivo': motivo.key,
            'p_nota': nota,
          },
        ),
        timeout: const Duration(seconds: 20),
        maxAttempts: 2,
        operation: 'set_product_stock',
      );
      return result;
    } on PostgrestException catch (error) {
      _throwStockError(
        error,
        productId: productId,
        label: label,
        delta: 0,
      );
    }
  }

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
    String nota = '',
  }) async {
    try {
      final result = await withTimeoutRetry(
        () => SupabaseService.client.rpc<int>(
          _rpcApplyDelta,
          params: {
            'p_product_id': productId,
            'p_delta': delta,
            'p_motivo': motivo.key,
            'p_venta_id': ventaId,
            'p_vendedor_id': vendedorId,
            'p_nota': nota,
          },
        ),
        timeout: const Duration(seconds: 20),
        maxAttempts: 2,
        operation: 'apply_product_stock_delta',
      );
      return result;
    } on PostgrestException catch (error) {
      _throwStockError(
        error,
        productId: productId,
        label: label,
        delta: delta,
      );
    } catch (error) {
      if (error is InsufficientStockException ||
          error is StockNotTrackedException ||
          error is StockConflictException ||
          error is StateError) {
        rethrow;
      }
      AppLogger.error(
        'RPC apply_product_stock_delta falló',
        error: error,
      );
      throw StateError('No se pudo actualizar stock: $error');
    }
  }

  Never _throwStockError(
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
      throw StateError(
        'Producto no encontrado: ${label.isNotEmpty ? label : productId}',
      );
    }
    if (msg.contains('invalid_stock')) {
      throw StateError('Stock inválido para ${label.isNotEmpty ? label : productId}');
    }
    throw StateError('No se pudo actualizar stock: ${error.message}');
  }

  Future<int> _readStockOrThrow(String productId, {String label = ''}) async {
    final row = await SupabaseService.client
        .from(_table)
        .select('stock')
        .eq('id', productId)
        .maybeSingle();
    if (row == null) {
      throw StateError(
        'Producto no encontrado: ${label.isNotEmpty ? label : productId}',
      );
    }
    final current = row['stock'] as int?;
    if (current == null) {
      throw StockNotTrackedException(productId: productId, label: label);
    }
    return current;
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
      fixedPrices: FixedPrices.fromJson(
        (row['fixed_prices'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  /// Columnas con GRANT UPDATE (036). Sin `id`/`tenant_id`/`stock`/`updated_at`.
  ///
  /// [includePhotos]: en import Excel va `false` para no pisar fotos ya cargadas
  /// si la caché local no las tiene.
  Map<String, dynamic> _toUpdateRow(
    Product product, {
    bool includePhotos = true,
  }) {
    final row = <String, dynamic>{
      'type': product.type.key,
      'marca': product.marca,
      'calibre': product.calibre,
      'codigo': product.codigo,
      'modelo': product.modelo,
      'descripcion': product.descripcion,
      'precio_usd': product.precioUsd,
      'stock_inicial': product.stockInicial,
      'rounds_per_box': product.roundsPerBox,
      // Siempre se escribe (la 041 ya está aplicada): null cuando el producto no
      // tiene precios fijos. Así un re-import limpia cualquier fixed_prices que
      // haya quedado mal seteado (p. ej. contaminación entre tenants).
      'fixed_prices': product.fixedPrices?.toJson(),
      'activo': true,
      // updated_at lo pone el trigger set_updated_at_trg (AR-23).
    };
    if (includePhotos) {
      final paths = ProductPhotoService.pathsForStorage(product);
      row['foto'] = product.foto;
      row['foto_url'] = paths.isNotEmpty ? paths.first : '';
      row['fotos'] = paths;
    }
    return row;
  }

  /// Columnas con GRANT INSERT (036), incluye identidad + tenant.
  Map<String, dynamic> _toInsertRow(Product product) {
    final row = _toUpdateRow(product, includePhotos: true);
    row['id'] = product.id;
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
