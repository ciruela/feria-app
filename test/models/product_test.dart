import 'package:app_feria/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

Product _municion({int? stock, int? inicial, int? rpb}) => Product(
      id: 'municion_1',
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '22LR',
      codigo: 'C-1',
      precioUsd: 10,
      stock: stock,
      stockInicial: inicial,
      roundsPerBox: rpb,
    );

void main() {
  group('ProductType', () {
    test('fromKey resuelve la clave', () {
      expect(ProductType.fromKey('municion'), ProductType.municion);
      expect(ProductType.fromKey('arma_corta'), ProductType.armaCorta);
      expect(ProductType.fromKey('arma_larga'), ProductType.armaLarga);
      expect(ProductType.fromKey('accesorios'), ProductType.accesorios);
    });

    test('fromKey cae en municion ante tipo desconocido (anti-crash)', () {
      // Una app vieja que lee un tipo agregado después NO debe crashear.
      expect(ProductType.fromKey('tipo_futuro'), ProductType.municion);
      expect(ProductType.fromKey(''), ProductType.municion);
    });
  });

  group('Product getters', () {
    test('flags de tipo', () {
      final m = _municion();
      expect(m.isMunicion, isTrue);
      expect(m.isArma, isFalse);
      expect(m.isAccesorios, isFalse);

      const arma = Product(
        id: 'a',
        type: ProductType.armaCorta,
        marca: 'glock',
        calibre: '9',
        codigo: 'X',
        precioUsd: 500,
      );
      expect(arma.isArma, isTrue);
      expect(arma.marcaUpper, 'GLOCK');

      const acc = Product(
        id: 'acc-1',
        type: ProductType.accesorios,
        marca: 'Accesorios',
        calibre: '',
        codigo: 'FUNDA-01',
        descripcion: 'Funda Glock 19',
        precioUsd: 45,
        stock: 10,
      );
      expect(acc.isAccesorios, isTrue);
      expect(acc.isArma, isFalse);
      expect(acc.isMunicion, isFalse);
      // Accesorio se vende por unidad y muestra su descripción en el carrito.
      expect(acc.cartQuantityUnit, 'unidades');
      expect(acc.cartDisplayDescription, 'Funda Glock 19');
      // Sin `modelo`, el título del accesorio es su nombre (no el código).
      expect(acc.modeloDisplay, 'Funda Glock 19');
    });

    test('modeloDisplay cae al código si no hay modelo', () {
      final m = _municion();
      expect(m.modeloDisplay, 'C-1');
      expect(m.copyWith(modelo: 'Blazer').modeloDisplay, 'Blazer');
    });

    test('inStock según stock', () {
      expect(_municion(stock: null).inStock, isTrue);
      expect(_municion(stock: 0).inStock, isFalse);
      expect(_municion(stock: 2).inStock, isTrue);
    });

    test('sellerShortTitle simplifica descripciones CCI', () {
      const m = Product(
        id: 'm',
        type: ProductType.municion,
        marca: 'CCI',
        calibre: '.22 LR',
        codigo: '20732',
        descripcion: 'C.22 30G LR VARMIT V-MAX (50)',
        precioUsd: 10,
        roundsPerBox: 50,
      );
      expect(m.sellerShortTitle, 'Varmit V-Max');
      expect(m.sellerTagLabels, contains('.22 LR'));
      expect(m.sellerTagLabels, contains('30 gr'));
      expect(m.sellerTagLabels, contains('50/caja'));
    });

    test('granos (peso de la punta) se deriva de la descripción', () {
      const m = Product(
        id: 'm',
        type: ProductType.municion,
        marca: 'CCI',
        calibre: '.22 LR',
        codigo: '20732',
        descripcion: 'C.22 40G LR MINI MAG 1235FPS CCI M.960 (50)',
        precioUsd: 10,
      );
      expect(m.granos, '40 gr');

      const sinDesc = Product(
        id: 'm2',
        type: ProductType.municion,
        marca: 'CCI',
        calibre: '.22 LR',
        codigo: 'x',
        precioUsd: 10,
      );
      expect(sinDesc.granos, '');

      const arma = Product(
        id: 'a',
        type: ProductType.armaLarga,
        marca: 'X',
        calibre: '.308',
        modelo: 'M700',
        codigo: '',
        descripcion: '40G algo',
        precioUsd: 100,
      );
      expect(arma.granos, ''); // solo aplica a munición
    });

    test('derivados de balas para munición', () {
      final m = _municion(stock: 3, inicial: 5, rpb: 50);
      expect(m.cajasDisponibles, 3);
      expect(m.balasDisponibles, 150);
      expect(m.balasIniciales, 250);
      expect(m.unidadesVendidas, 2);
      expect(m.balasVendidas, 100);
    });

    test('unidadesVendidas nunca es negativa', () {
      final m = _municion(stock: 8, inicial: 5, rpb: 50);
      expect(m.unidadesVendidas, 0);
    });

    test('derivados null cuando faltan datos o es arma', () {
      expect(_municion(stock: null, rpb: 50).balasDisponibles, isNull);
      const arma = Product(
        id: 'a',
        type: ProductType.armaLarga,
        marca: 'm',
        calibre: 'c',
        codigo: 'k',
        precioUsd: 1,
        stock: 4,
      );
      expect(arma.cajasDisponibles, isNull);
      expect(arma.balasVendidas, isNull);
    });
  });

  group('Product JSON', () {
    test('roundtrip fromJson/toJson', () {
      final m = _municion(stock: 3, inicial: 5, rpb: 50).copyWith(
        modelo: 'Blazer',
        descripcion: 'interno',
        foto: 'local.jpg',
        fotoUrls: ['a.jpg', 'b.jpg'],
      );
      final json = m.toJson();
      final back = Product.fromJson(json);
      expect(back.id, m.id);
      expect(back.type, m.type);
      expect(back.roundsPerBox, 50);
      expect(back.fotoUrls, ['a.jpg', 'b.jpg']);
      expect(back.descripcion, 'interno');
    });

    test('fromJson soporta fotoUrl legacy y filtra vacíos', () {
      final p = Product.fromJson({
        'id': 'x',
        'type': 'municion',
        'marca': 'CCI',
        'calibre': '22',
        'codigo': 'C',
        'precioUsd': 5,
        'fotoUrls': ['  ok.jpg  ', ''],
        'fotoUrl': 'legacy.jpg',
      });
      expect(p.fotoUrls.first, 'legacy.jpg');
      expect(p.fotoUrls.contains('ok.jpg'), isTrue);
      expect(p.hasNetworkPhoto, isTrue);
    });

    test('toJson omite campos vacíos/null', () {
      final json = _municion().toJson();
      expect(json.containsKey('modelo'), isFalse);
      expect(json.containsKey('stock'), isFalse);
      expect(json.containsKey('roundsPerBox'), isFalse);
    });
  });
}
