import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_member.dart';
import 'active_tenant.dart';
import 'supabase_service.dart';

class TeamFetchResult {
  const TeamFetchResult({
    required this.members,
    this.migrationPending = false,
  });

  final List<TeamMember> members;
  final bool migrationPending;
}

class TeamInviteResult {
  const TeamInviteResult({
    required this.email,
    required this.emailSent,
    required this.invitedNewUser,
  });

  final String email;
  final bool emailSent;
  final bool invitedNewUser;
}

class TeamService {
  Future<TeamFetchResult> fetchMembers() async {
    try {
      final rows = await SupabaseService.client.rpc('list_tenant_members');
      return TeamFetchResult(
        members: (rows as List<dynamic>)
            .map((row) => TeamMember.fromRow(row as Map<String, dynamic>))
            .toList(),
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        return TeamFetchResult(
          members: await _fetchMembersFallback(),
          migrationPending: true,
        );
      }
      rethrow;
    }
  }

  /// Sin migración 011: lista miembros sin email ajeno (solo el tuyo).
  Future<List<TeamMember>> _fetchMembersFallback() async {
    // Filtro por tenant activo (no solo RLS): un platform admin pasa el RLS de
    // todas las armerías y sin esto vería miembros de otras.
    final tenantId = activeTenantIdFromJwt();
    var query = SupabaseService.client
        .from('memberships')
        .select('user_id, nombre, rol, activo, created_at');
    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }
    final rows = await query.order('created_at');

    final currentUser = SupabaseService.client.auth.currentUser;
    final currentId = currentUser?.id ?? '';
    final currentEmail = currentUser?.email ?? '';

    return (rows as List<dynamic>).map((raw) {
      final row = raw as Map<String, dynamic>;
      final userId = row['user_id'] as String;
      return TeamMember(
        userId: userId,
        email: userId == currentId ? currentEmail : '',
        nombre: row['nombre'] as String? ?? '',
        rol: row['rol'] as String? ?? 'admin',
        activo: row['activo'] as bool? ?? true,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  /// Invita por email. Si la persona no tiene cuenta, Auth le manda el mail
  /// de invitación; si ya tiene, solo se agrega a la armería.
  Future<TeamInviteResult> invite({
    required String email,
    String nombre = '',
    String rol = 'admin',
  }) async {
    final map = await _invokeFunction(
      'invite-team-member',
      {
        'email': email.trim(),
        'nombre': nombre.trim(),
        'rol': rol,
      },
      fallbackMessage: 'No se pudo invitar',
    );

    final status = map['status'] as String? ?? 'added';
    return TeamInviteResult(
      email: map['email'] as String? ?? email.trim(),
      emailSent: map['email_sent'] == true || status == 'invited',
      invitedNewUser: status == 'invited',
    );
  }

  static Map<String, dynamic> _asStringKeyedMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'error': data.trim()};
      }
    }
    return const {};
  }

  static String _errorMessage(
    Map<String, dynamic> map,
    int status, {
    String fallback = 'No se pudo completar la operación',
  }) {
    final message = (map['error'] as String?)?.trim();
    if (message != null && message.isNotEmpty) return message;
    final msg = (map['message'] as String?)?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
    return '$fallback ($status)';
  }

  static Map<String, dynamic> _functionErrorMap(FunctionException error) {
    final fromDetails = _asStringKeyedMap(error.details);
    if (fromDetails.isNotEmpty) return fromDetails;
    return const {};
  }

  static const _removeTimeout = Duration(seconds: 20);

  static bool _isMissingRpc(PostgrestException error) {
    if (error.code == 'PGRST202' || error.code == 'PGRST203') return true;
    final msg = error.message.toLowerCase();
    return msg.contains('could not find the function') ||
        msg.contains('could not choose the best candidate function') ||
        msg.contains('function') && msg.contains('does not exist');
  }

  Map<String, dynamic> _rpcParams(String userId, {String? tenantId}) {
    final scoped = tenantId?.trim();
    if (scoped == null || scoped.isEmpty) {
      throw StateError(
        'No hay armería activa. Volvé al selector e ingresá de nuevo.',
      );
    }
    return {
      'p_user_id': userId,
      'p_tenant_id': scoped,
    };
  }

  Future<void> _deactivateViaRpc(String userId, {String? tenantId}) async {
    await SupabaseService.client.rpc(
      'deactivate_tenant_member',
      params: _rpcParams(userId, tenantId: tenantId),
    );
  }

  Future<void> _removeViaRpc(String userId, {String? tenantId}) async {
    await SupabaseService.client.rpc(
      'remove_tenant_member',
      params: _rpcParams(userId, tenantId: tenantId),
    );
  }

  static Never _throwRpcError(PostgrestException error) {
    final message = error.message.trim();
    throw StateError(
      message.isNotEmpty ? message : 'No se pudo quitar del equipo',
    );
  }

  static bool _isRecoverableRemoveError(PostgrestException error) {
    final msg = error.message.toLowerCase();
    return msg.contains('no está en el equipo') ||
        msg.contains('not in the team');
  }

  Future<void> removeMember(String userId, {String? tenantId}) async {
    await _withTimeout(() async {
      final scopedTenant = tenantId?.trim();

      // 1) Borrado duro (elimina la fila de membership).
      try {
        await _removeViaRpc(userId, tenantId: scopedTenant);
        return;
      } on PostgrestException catch (error) {
        if (!_isMissingRpc(error) && !_isRecoverableRemoveError(error)) {
          _throwRpcError(error);
        }
      }

      // 2) Soft delete (desactivar membership).
      try {
        await _deactivateViaRpc(userId, tenantId: scopedTenant);
        return;
      } on PostgrestException catch (error) {
        if (!_isMissingRpc(error)) _throwRpcError(error);
      }

      // 3) Edge Function (limpia active_tenant en Auth).
      final body = <String, dynamic>{'user_id': userId};
      if (scopedTenant != null && scopedTenant.isNotEmpty) {
        body['tenant_id'] = scopedTenant;
      }

      await _invokeFunction(
        'remove-team-member',
        body,
        fallbackMessage: 'No se pudo eliminar del equipo',
      );
    });
  }

  Future<void> _withTimeout(Future<void> Function() action) async {
    try {
      await action().timeout(_removeTimeout);
    } on TimeoutException {
      throw StateError(
        'La operación tardó demasiado. Revisá la conexión e intentá de nuevo.',
      );
    }
  }

  /// @deprecated Usar [removeMember]. Mantenido por compatibilidad con RPC.
  Future<void> deactivate(String userId, {String? tenantId}) async {
    try {
      await _deactivateViaRpc(userId, tenantId: tenantId);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        await removeMember(userId, tenantId: tenantId);
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _invokeFunction(
    String name,
    Map<String, dynamic> body, {
    String fallbackMessage = 'No se pudo completar la operación',
  }) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        name,
        body: body,
      );
      final map = _asStringKeyedMap(response.data);
      if (response.status >= 400) {
        throw StateError(_errorMessage(
          map,
          response.status,
          fallback: fallbackMessage,
        ));
      }
      return map;
    } on FunctionException catch (error) {
      final map = _functionErrorMap(error);
      throw StateError(_errorMessage(
        map,
        error.status,
        fallback: fallbackMessage,
      ));
    }
  }
}
