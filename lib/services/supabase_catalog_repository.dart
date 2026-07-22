import '../models/product.dart';
import 'product_photo_service.dart';
import 'supabase_service.dart';

class SupabaseCatalogRepository {
  static const _table = 'productos';

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

  Product productFromRow(Map<String, dynamic> row) => _fromRow(row);

  Future<void> decrementStock(String productId, int quantity) async {
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
  }

  Product _fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      type: ProductType.fromKey(row['type'] as String),
      marca: row['marca'] as String,
      calibre: row['calibre'] as String,
      codigo: row['codigo'] as String? ?? '',
      modelo: row['modelo'] as String? ?? '',
      precioUsd: (row['precio_usd'] as num).toDouble(),
      foto: row['foto'] as String? ?? '',
      fotoUrls: ProductPhotoService.parsePathsFromRow(row),
      stock: row['stock'] as int?,
    );
  }

  Map<String, dynamic> _toRow(Product product) {
    final paths = ProductPhotoService.pathsForStorage(product);

    return {
      'id': product.id,
      'type': product.type.key,
      'marca': product.marca,
      'calibre': product.calibre,
      'codigo': product.codigo,
      'modelo': product.modelo,
      'precio_usd': product.precioUsd,
      'foto': product.foto,
      'foto_url': paths.isNotEmpty ? paths.first : '',
      'fotos': paths,
      'stock': product.stock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
