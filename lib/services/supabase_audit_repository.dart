import '../models/audit_entry.dart';
import 'supabase_service.dart';

class SupabaseAuditRepository {
  static const _table = 'audit_log';

  Future<void> insert({
    required String accion,
    String? actorId,
    String actorNombre = '',
    String entidad = '',
    String entidadId = '',
    String detalle = '',
  }) async {
    await SupabaseService.client.from(_table).insert({
      if (actorId != null && actorId.isNotEmpty) 'actor_id': actorId,
      'actor_nombre': actorNombre,
      'accion': accion,
      'entidad': entidad,
      'entidad_id': entidadId,
      'detalle': detalle,
    });
  }

  Future<List<AuditEntry>> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => AuditEntry.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<AuditEntry>> fetchRecent({int limit = 300}) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => AuditEntry.fromRow(row as Map<String, dynamic>))
        .toList();
  }
}
