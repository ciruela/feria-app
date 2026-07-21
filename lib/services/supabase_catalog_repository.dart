import '../models/product.dart';
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
      fotoUrl: row['foto_url'] as String? ?? '',
      stock: row['stock'] as int?,
    );
  }

  Map<String, dynamic> _toRow(Product product) {
    return {
      'id': product.id,
      'type': product.type.key,
      'marca': product.marca,
      'calibre': product.calibre,
      'codigo': product.codigo,
      'modelo': product.modelo,
      'precio_usd': product.precioUsd,
      'foto': product.foto,
      'foto_url': product.fotoUrl,
      'stock': product.stock,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
