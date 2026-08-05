import 'package:app_feria/models/platform_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('aggregatePlatformMetrics', () {
    test('agrega ventas y vendedores por tenant', () {
      final metrics = aggregatePlatformMetrics(
        tenants: [
          {
            'id': 't1',
            'nombre': 'World Guns',
            'slug': 'world-guns',
            'activo': true,
          },
          {
            'id': 't2',
            'nombre': 'Urban Tactical',
            'slug': 'urban-tactical',
            'activo': true,
          },
        ],
        ventas: [
          {
            'tenant_id': 't1',
            'total_ars': 1000,
            'total_usd': 10,
            'anulada': false,
          },
          {
            'tenant_id': 't1',
            'total_ars': 500,
            'total_usd': 0,
            'anulada': false,
          },
          {
            'tenant_id': 't2',
            'total_ars': 200,
            'total_usd': 5,
            'anulada': true,
          },
        ],
        vendedores: [
          {'tenant_id': 't1', 'activo': true},
          {'tenant_id': 't1', 'activo': true},
          {'tenant_id': 't2', 'activo': true},
        ],
      );

      expect(metrics.tenantCount, 2);
      expect(metrics.activeTenants, 2);
      expect(metrics.salesCount, 2);
      expect(metrics.totalArs, 1500);
      expect(metrics.totalUsd, 10);
      expect(metrics.sellerCount, 3);

      expect(metrics.tenants.first.slug, 'world-guns');
      expect(metrics.tenants.first.salesCount, 2);
      expect(metrics.tenants.first.totalArs, 1500);
      expect(metrics.tenants.first.sellerCount, 2);

      final urban = metrics.tenants.firstWhere((t) => t.slug == 'urban-tactical');
      expect(urban.salesCount, 0);
      expect(urban.sellerCount, 1);
    });
  });
}
