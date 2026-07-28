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

  Future<void> invite({
    required String email,
    String nombre = '',
    String rol = 'admin',
  }) async {
    try {
      await SupabaseService.client.rpc(
        'invite_user_to_tenant',
        params: {
          'p_email': email.trim(),
          'p_nombre': nombre.trim(),
          'p_rol': rol,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw StateError(
          'Falta aplicar la migración de equipo en Supabase. '
          'Ejecutá supabase/migrations/011_team_members.sql en el SQL Editor.',
        );
      }
      rethrow;
    }
  }

  Future<void> deactivate(String userId) async {
    try {
      await SupabaseService.client.rpc(
        'deactivate_tenant_member',
        params: {'p_user_id': userId},
      );
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202') {
        throw StateError(
          'Falta aplicar la migración de equipo en Supabase. '
          'Ejecutá supabase/migrations/011_team_members.sql en el SQL Editor.',
        );
      }
      rethrow;
    }
  }
}
