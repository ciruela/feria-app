import 'package:app_feria/models/product.dart';
import 'package:app_feria/widgets/employee/catalog_product_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogProductTitle', () {
    test('munición muestra marca y nombre corto', () {
      const product = Product(
        id: 'm',
        type: ProductType.municion,
        marca: 'MAGTECH',
        calibre: '9mm Luger',
        codigo: 'MT-9-50',
        descripcion: '9MM LUGER 124GR FMJ (50)',
        precioUsd: 12,
        roundsPerBox: 50,
      );

      expect(catalogProductTitle(product), contains('MAGTECH'));
      expect(catalogProductTitle(product), isNot('MT-9-50'));
    });

    test('arma mantiene marca y modelo', () {
      const product = Product(
        id: 'a',
        type: ProductType.armaCorta,
        marca: 'BERSA',
        calibre: '.380 ACP',
        codigo: 'BP9-002',
        modelo: 'Thunder 380',
        precioUsd: 320,
      );

      expect(catalogProductTitle(product), 'BERSA Thunder 380');
    });
  });

  group('catalogProductSubtitle', () {
    test('munición incluye código, calibre y stock', () {
      const product = Product(
        id: 'm',
        type: ProductType.municion,
        marca: 'CCI',
        calibre: '.22 LR',
        codigo: '20732',
        descripcion: 'C.22 30G LR VARMIT V-MAX (50)',
        precioUsd: 10,
        stock: 12,
        roundsPerBox: 50,
      );

      expect(catalogProductSubtitle(product), '20732 · Cal. .22 LR · 12 cajas');
    });
  });
}
