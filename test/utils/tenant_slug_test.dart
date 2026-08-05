import 'package:app_feria/utils/tenant_slug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slugifyTenantName', () {
    test('convierte a minúsculas y reemplaza espacios', () {
      expect(slugifyTenantName('World Guns'), 'world-guns');
    });

    test('quita acentos y ñ', () {
      expect(slugifyTenantName('Armería Peña'), 'armeria-pena');
    });

    test('colapsa símbolos y recorta guiones', () {
      expect(slugifyTenantName('  Pepe & Cía!! '), 'pepe-cia');
    });

    test('vacío devuelve armeria', () {
      expect(slugifyTenantName('   '), 'armeria');
      expect(slugifyTenantName('###'), 'armeria');
    });

    test('evita slugs reservados', () {
      expect(slugifyTenantName('admin'), 'admin-shop');
      expect(slugifyTenantName('APP'), 'app-shop');
      expect(slugifyTenantName('default'), 'default-shop');
    });
  });

  group('tenantSlugKey', () {
    test('ignora guiones al comparar', () {
      expect(tenantSlugMatches('urban-tactical', 'urbantactical'), isTrue);
      expect(tenantSlugMatches('world-guns', 'worldguns'), isTrue);
    });
  });

  group('tenantPortalUrl', () {
    test('genera subdominio sin guiones', () {
      expect(
        tenantPortalUrl('urban-tactical'),
        'https://urbantactical.armenext.com',
      );
      expect(
        tenantPortalUrl('world-guns'),
        'https://worldguns.armenext.com',
      );
    });
  });

  group('tenantSlugToSubdomain', () {
    test('quita guiones del slug', () {
      expect(tenantSlugToSubdomain('mi-armeria'), 'miarmeria');
    });
  });
}
