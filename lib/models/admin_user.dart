class AdminUser {
  const AdminUser({
    required this.id,
    required this.nombre,
    required this.pin,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String pin;
  final bool activo;

  AdminUser copyWith({
    String? id,
    String? nombre,
    String? pin,
    bool? activo,
  }) {
    return AdminUser(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      pin: pin ?? this.pin,
      activo: activo ?? this.activo,
    );
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      pin: json['pin'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'pin': pin,
        'activo': activo,
      };
}
