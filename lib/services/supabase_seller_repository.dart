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

  Future<void> upsert(Seller seller) async {
    await SupabaseService.client.from(_table).upsert(_toRow(seller));
  }

  Future<void> setActive(String id, {required bool activo}) async {
    await SupabaseService.client.from(_table).update({
      'activo': activo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> updateName(String id, String nombre) async {
    await SupabaseService.client.from(_table).update({
      'nombre': nombre,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await SupabaseService.client
        .from('ventas')
        .update({'vendedor_id': null})
        .eq('vendedor_id', id);

    await SupabaseService.client.from(_table).delete().eq('id', id);
  }

  Seller sellerFromRow(Map<String, dynamic> row) => _fromRow(row);

  Seller _fromRow(Map<String, dynamic> row) {
    return Seller(
      id: row['id'] as String,
      nombre: row['nombre'] as String,
      activo: row['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toRow(Seller seller) {
    return {
      'id': seller.id,
      'nombre': seller.nombre,
      'activo': seller.activo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
