class TeamMember {
  const TeamMember({
    required this.userId,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String nombre;
  final String rol;
  final bool activo;
  final DateTime createdAt;

  bool get isOwner => rol == 'owner';

  String get displayName {
    if (nombre.trim().isNotEmpty) return nombre.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Usuario';
  }

  factory TeamMember.fromRow(Map<String, dynamic> row) {
    return TeamMember(
      userId: row['user_id'] as String,
      email: row['email'] as String? ?? '',
      nombre: row['nombre'] as String? ?? '',
      rol: row['rol'] as String? ?? 'admin',
      activo: row['activo'] as bool? ?? true,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
