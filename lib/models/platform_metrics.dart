/// Métricas agregadas del panel super admin.
class PlatformMetrics {
  const PlatformMetrics({
    required this.tenantCount,
    required this.activeTenants,
    required this.sellerCount,
    required this.salesCount,
    required this.totalArs,
    required this.totalUsd,
    required this.tenants,
  });

  final int tenantCount;
  final int activeTenants;
  final int sellerCount;
  final int salesCount;
  final double totalArs;
  final double totalUsd;
  final List<PlatformTenantMetrics> tenants;

  Map<String, dynamic> toJson() => {
        'tenant_count': tenantCount,
        'active_tenants': activeTenants,
        'seller_count': sellerCount,
        'sales_count': salesCount,
        'total_ars': totalArs,
        'total_usd': totalUsd,
        'tenants': tenants.map((t) => t.toJson()).toList(),
      };

  factory PlatformMetrics.fromJson(Map<String, dynamic> json) {
    final tenantRows = json['tenants'] as List<dynamic>? ?? const [];
    return PlatformMetrics(
      tenantCount: (json['tenant_count'] as num?)?.toInt() ?? 0,
      activeTenants: (json['active_tenants'] as num?)?.toInt() ?? 0,
      sellerCount: (json['seller_count'] as num?)?.toInt() ?? 0,
      salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
      totalArs: (json['total_ars'] as num?)?.toDouble() ?? 0,
      totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
      tenants: tenantRows
          .map(
            (row) => PlatformTenantMetrics.fromJson(
              (row as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class PlatformTenantMetrics {
  const PlatformTenantMetrics({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.activo,
    required this.salesCount,
    required this.totalArs,
    required this.totalUsd,
    required this.sellerCount,
  });

  final String id;
  final String nombre;
  final String slug;
  final bool activo;
  final int salesCount;
  final double totalArs;
  final double totalUsd;
  final int sellerCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'slug': slug,
        'activo': activo,
        'sales_count': salesCount,
        'total_ars': totalArs,
        'total_usd': totalUsd,
        'seller_count': sellerCount,
      };

  factory PlatformTenantMetrics.fromJson(Map<String, dynamic> json) {
    return PlatformTenantMetrics(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? 'Armería',
      slug: json['slug'] as String? ?? '',
      activo: json['activo'] as bool? ?? true,
      salesCount: (json['sales_count'] as num?)?.toInt() ?? 0,
      totalArs: (json['total_ars'] as num?)?.toDouble() ?? 0,
      totalUsd: (json['total_usd'] as num?)?.toDouble() ?? 0,
      sellerCount: (json['seller_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Agrega métricas cross-tenant (misma lógica que la Edge Function).
PlatformMetrics aggregatePlatformMetrics({
  required List<Map<String, dynamic>> tenants,
  required List<Map<String, dynamic>> ventas,
  required List<Map<String, dynamic>> vendedores,
}) {
  final byTenant = <String, PlatformTenantMetrics>{};
  for (final row in tenants) {
    final id = row['id'] as String? ?? '';
    if (id.isEmpty) continue;
    byTenant[id] = PlatformTenantMetrics(
      id: id,
      nombre: (row['nombre'] as String?)?.trim().isNotEmpty == true
          ? row['nombre'] as String
          : 'Armería',
      slug: (row['slug'] as String?) ?? '',
      activo: row['activo'] as bool? ?? true,
      salesCount: 0,
      totalArs: 0,
      totalUsd: 0,
      sellerCount: 0,
    );
  }

  var totalArs = 0.0;
  var totalUsd = 0.0;
  var salesCount = 0;

  for (final row in ventas) {
    if (row['anulada'] == true) continue;
    final tenantId = row['tenant_id'] as String? ?? '';
    final ars = (row['total_ars'] as num?)?.toDouble() ?? 0;
    final usd = (row['total_usd'] as num?)?.toDouble() ?? 0;
    totalArs += ars;
    totalUsd += usd;
    salesCount += 1;
    final current = byTenant[tenantId];
    if (current == null) continue;
    byTenant[tenantId] = PlatformTenantMetrics(
      id: current.id,
      nombre: current.nombre,
      slug: current.slug,
      activo: current.activo,
      salesCount: current.salesCount + 1,
      totalArs: current.totalArs + ars,
      totalUsd: current.totalUsd + usd,
      sellerCount: current.sellerCount,
    );
  }

  for (final row in vendedores) {
    final tenantId = row['tenant_id'] as String? ?? '';
    final current = byTenant[tenantId];
    if (current == null) continue;
    byTenant[tenantId] = PlatformTenantMetrics(
      id: current.id,
      nombre: current.nombre,
      slug: current.slug,
      activo: current.activo,
      salesCount: current.salesCount,
      totalArs: current.totalArs,
      totalUsd: current.totalUsd,
      sellerCount: current.sellerCount + 1,
    );
  }

  final tenantList = byTenant.values.toList()
    ..sort((a, b) => b.totalArs.compareTo(a.totalArs));

  return PlatformMetrics(
    tenantCount: tenants.length,
    activeTenants: tenants.where((t) => t['activo'] == true).length,
    sellerCount: vendedores.length,
    salesCount: salesCount,
    totalArs: totalArs,
    totalUsd: totalUsd,
    tenants: tenantList,
  );
}
