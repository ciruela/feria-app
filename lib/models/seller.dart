class Seller {
  const Seller({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  final String id;
  final String nombre;
  final bool activo;

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'activo': activo,
    };
  }
}
