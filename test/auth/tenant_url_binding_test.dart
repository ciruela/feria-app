import 'package:app_feria/auth/tenant_url_binding.dart';
import 'package:app_feria/services/tenant_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterByBoundTenantSlug', () {
    const worldGuns = TenantOption(
      id: 'wg-id',
      nombre: 'World Guns',
      slug: 'world-guns',
      rol: 'owner',
    );
    const urban = TenantOption(
      id: 'ut-id',
      nombre: 'Urban Tactical',
      slug: 'urban-tactical',
      rol: 'owner',
    );

    test('filtra por slug con guiones vs subdominio sin guiones', () {
      final filtered = filterByBoundTenantSlug(
        items: [worldGuns, urban],
        boundSlug: 'urbantactical',
        slugOf: (m) => m.slug,
      );

      expect(filtered, [urban]);
    });

    test('devuelve vacío si la cuenta no pertenece al tenant de la URL', () {
      final filtered = filterByBoundTenantSlug(
        items: [worldGuns],
        boundSlug: 'urbantactical',
        slugOf: (m) => m.slug,
      );

      expect(filtered, isEmpty);
    });

    test('sin bound slug conserva todas las memberships', () {
      final filtered = filterByBoundTenantSlug(
        items: [worldGuns, urban],
        boundSlug: '',
        slugOf: (m) => m.slug,
      );

      expect(filtered, [worldGuns, urban]);
    });
  });
}
