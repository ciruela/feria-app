import '../models/seller.dart';
import 'supabase_service.dart';

class SupabaseSellerRepository {
  static const _table = 'vendedores';

  Future<List<Seller>> fetchAll() async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .order('nombre');

    return (rows as List<dynamic>)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Seller _fromRow(Map<String, dynamic> row) {
    return Seller(
      id: row['id'] as String,
      nombre: row['nombre'] as String,
      activo: row['activo'] as bool? ?? true,
    );
  }
}
