import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_member.dart';
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
    final rows = await SupabaseService.client
        .from('memberships')
        .select('user_id, nombre, rol, activo, created_at')
        .order('created_at');

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

  Future<void> _deactivateViaRpc(String userId) async {
    await SupabaseService.client.rpc(
      'deactivate_tenant_member',
      params: {'p_user_id': userId},
    );
  }

  Future<void> removeMember(String userId, {String? tenantId}) async {
    final body = <String, dynamic>{'user_id': userId};
    final scopedTenant = tenantId?.trim();
    if (scopedTenant != null && scopedTenant.isNotEmpty) {
      body['tenant_id'] = scopedTenant;
    }

    try {
      await _invokeFunction(
        'remove-team-member',
        body,
        fallbackMessage: 'No se pudo eliminar del equipo',
      );
    } on StateError catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('not found') ||
          message.contains('404') ||
          message.contains('function')) {
        await _deactivateViaRpc(userId);
        return;
      }
      rethrow;
    }
  }

  /// @deprecated Usar [removeMember]. Mantenido por compatibilidad con RPC.
  Future<void> deactivate(String userId) async {
    try {
      await _deactivateViaRpc(userId);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        await removeMember(userId);
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
