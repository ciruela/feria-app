/// Entidades auditables (para filtrar el registro de actividad).
class AuditEntidad {
  static const producto = 'producto';
  static const stock = 'stock';
  static const precio = 'precio';
  static const tipoCambio = 'tipo_cambio';
  static const vendedor = 'vendedor';
  static const administrador = 'administrador';
  static const venta = 'venta';
  static const excel = 'excel';
  static const acceso = 'acceso';

  static const all = [
    producto,
    stock,
    precio,
    tipoCambio,
    vendedor,
    administrador,
    venta,
    excel,
    acceso,
  ];

  static String label(String entidad) {
    switch (entidad) {
      case producto:
        return 'Productos';
      case stock:
        return 'Stock';
      case precio:
        return 'Precios';
      case tipoCambio:
        return 'Tipo de cambio';
      case vendedor:
        return 'Vendedores';
      case administrador:
        return 'Administradores';
      case venta:
        return 'Ventas';
      case excel:
        return 'Excel';
      case acceso:
        return 'Accesos';
      default:
        return entidad;
    }
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.accion,
    required this.createdAt,
    this.actorId,
    this.actorNombre = '',
    this.entidad = '',
    this.entidadId = '',
    this.detalle = '',
  });

  final String id;
  final String accion;
  final DateTime createdAt;
  final String? actorId;
  final String actorNombre;
  final String entidad;
  final String entidadId;
  final String detalle;

  factory AuditEntry.fromRow(Map<String, dynamic> row) {
    return AuditEntry(
      id: row['id'] as String,
      accion: row['accion'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      actorId: row['actor_id'] as String?,
      actorNombre: row['actor_nombre'] as String? ?? '',
      entidad: row['entidad'] as String? ?? '',
      entidadId: row['entidad_id'] as String? ?? '',
      detalle: row['detalle'] as String? ?? '',
    );
  }
}
