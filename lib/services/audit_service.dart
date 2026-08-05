import 'package:flutter/foundation.dart';

import '../models/audit_entry.dart';
import 'supabase_audit_repository.dart';
import 'supabase_service.dart';

/// Registro de actividad de administradores. Singleton para poder llamarse
/// desde cualquier servicio sin plomería de providers.
class AuditService {
  AuditService._();
  static final AuditService instance = AuditService._();

  final SupabaseAuditRepository _repo = SupabaseAuditRepository();

  String? _actorId;
  String _actorNombre = '';

  String get actorNombre => _actorNombre;

  void setActor({String? id, required String nombre}) {
    _actorId = id;
    _actorNombre = nombre;
  }

  void clearActor() {
    _actorId = null;
    _actorNombre = '';
  }

  /// Registra una acción. Best-effort: nunca lanza (no bloquea la operación).
  /// [actorNombre] puede sobreescribir el nombre visible (ej. vendedor).
  /// La identidad (`actor_id`) la fija el servidor con `auth.uid()` (AR-7).
  Future<void> log({
    required String accion,
    String entidad = '',
    String entidadId = '',
    String detalle = '',
    String? actorId,
    String? actorNombre,
  }) async {
    if (!SupabaseService.isConfigured) return;
    var nombre = (actorNombre ?? _actorNombre).trim();
    if (nombre.isEmpty) {
      nombre =
          SupabaseService.client.auth.currentUser?.email?.trim() ?? 'Sistema';
    }
    try {
      await _repo.insert(
        accion: accion,
        // Conservado en la firma por callers existentes; el server lo ignora.
        actorId: actorId ?? _actorId,
        actorNombre: nombre,
        entidad: entidad,
        entidadId: entidadId,
        detalle: detalle,
      );
    } catch (error) {
      debugPrint('AuditService.log: $error');
    }
  }

  Future<List<AuditEntry>> fetchForDay(DateTime day) => _repo.fetchForDay(day);

  Future<List<AuditEntry>> fetchRecent({int limit = 300}) =>
      _repo.fetchRecent(limit: limit);
}
