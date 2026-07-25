import '../models/admin_user.dart';
import 'supabase_service.dart';

class SupabaseAdminRepository {
  static const _table = 'administradores';

  Future<List<AdminUser>> fetchAll() async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .order('nombre');

    return (rows as List<dynamic>)
        .map((row) => _fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsert(AdminUser admin) async {
    await SupabaseService.client.from(_table).upsert(_toRow(admin));
  }

  Future<void> setActive(String id, {required bool activo}) async {
    await SupabaseService.client.from(_table).update({
      'activo': activo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await SupabaseService.client.from(_table).delete().eq('id', id);
  }

  AdminUser adminFromRow(Map<String, dynamic> row) => _fromRow(row);

  AdminUser _fromRow(Map<String, dynamic> row) {
    return AdminUser(
      id: row['id'] as String,
      nombre: row['nombre'] as String,
      pin: row['pin'] as String? ?? '',
      activo: row['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> _toRow(AdminUser admin) {
    return {
      'id': admin.id,
      'nombre': admin.nombre,
      'pin': admin.pin,
      'activo': admin.activo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
