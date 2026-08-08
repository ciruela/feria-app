import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_search_index.dart';
import 'package:app_feria/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texto legal RENAR que "envenena" las descripciones: aparecer aquí NO debe
/// hacer que un producto entre por la pasada fuerte.
const _renar =
    'La venta de armas, municiones e insumos está sujeta a la Ley Nacional '
    'de Armas y Explosivos.';

Product _arma({
  required String id,
  required String marca,
  required String modelo,
  String calibre = '9MM',
  String codigo = '',
  String descripcion = _renar,
}) =>
    Product(
      id: id,
      type: ProductType.armaCorta,
      marca: marca,
      calibre: calibre,
      codigo: codigo.isEmpty ? id : codigo,
      modelo: modelo,
      descripcion: descripcion,
      precioUsd: 500,
      stock: 5,
    );

Product _municion({
  required String id,
  required String marca,
  required String codigo,
  String calibre = '9MM',
  String descripcion = _renar,
}) =>
    Product(
      id: id,
      type: ProductType.municion,
      marca: marca,
      calibre: calibre,
      codigo: codigo,
      descripcion: descripcion,
      precioUsd: 20,
      stock: 5,
    );

List<Product> _search(List<Product> catalog, String query) =>
    searchCatalog(catalog, query, ProductSearchIndex.fromProduct);

void main() {
  group('normalizar / compactar', () {
    test('normalizar pasa a mayúsculas y quita acentos', () {
      expect(normalizar('Munición'), 'MUNICION');
      expect(normalizar('Ñandú Áéíóú Ü'), 'NANDU AEIOU U');
      expect(normalizar('.308 win'), '.308 WIN');
    });

    test('compactar deja solo [A-Z0-9]', () {
      expect(compactar('.308 win'), '308WIN');
      expect(compactar('30-06 SPRG'), '3006SPRG');
      expect(compactar('9 mm'), '9MM');
      expect(compactar('.45Acp'), '45ACP');
    });
  });

  group('filtros marca / calibre', () {
    test('sameMarca ignora mayúsculas y acentos', () {
      expect(sameMarca('Hornady', 'HORNADY'), isTrue);
      expect(sameMarca('Munición Sur', 'MUNICION SUR'), isTrue);
      expect(sameMarca('CCI', 'FEDERAL'), isFalse);
    });

    test('sameCalibre unifica grafías frecuentes', () {
      expect(sameCalibre('.22', '.22 LR'), isTrue);
      expect(sameCalibre('.9', '9mm'), isTrue);
      expect(sameCalibre('.9', 'C.9'), isTrue);
      expect(sameCalibre('.308', '7.62x51'), isTrue);
      expect(sameCalibre('.30', '.308'), isFalse);
      expect(sameCalibre('', kCalibreSinEtiqueta), isTrue);
    });

    test('calibreKey no mezcla .30 con .308', () {
      expect(calibreKey('.30'), '30');
      expect(calibreKey('.308'), '308');
      expect(calibreKey('.22 LR'), '22');
      expect(calibreKey('.9'), '9');
    });
  });

  group('ProductSearchIndex.fromProduct', () {
    test('cruza campos: principal contiene marca + modelo juntos', () {
      final p = _arma(id: 'ac1', marca: 'Glock', modelo: 'Pistola Glock 19 gen 5 FS');
      final idx = ProductSearchIndex.fromProduct(p);
      expect(idx.principal.contains('GLOCK'), isTrue);
      expect(idx.principal.contains('PISTOLA GLOCK 19 GEN 5 FS'), isTrue);
      // La descripción legal se mantiene aparte del índice principal.
      expect(idx.principal.contains('MUNICIONES'), isFalse);
      expect(idx.descripcion.contains('MUNICIONES'), isTrue);
    });
  });

  group('searchCatalog', () {
    final glocks = [
      _arma(id: 'g17', marca: 'Glock', modelo: 'Pistola Glock 17 gen 5 FS'),
      _arma(id: 'g19g3', marca: 'Glock', modelo: 'Pistola Glock 19 gen 3'),
      _arma(id: 'g19g4', marca: 'Glock', modelo: 'Pistola Glock 19 gen 4'),
      _arma(id: 'g19g5', marca: 'Glock', modelo: 'Pistola Glock 19 gen 5 FS'),
      _arma(id: 'g26', marca: 'Glock', modelo: 'Pistola Glock 26'),
      // Otra marca con "FS" para asegurar que "glock fs" no la traiga.
      _arma(id: 'axe', marca: 'Bull Armory', modelo: 'AXE FS PRO'),
    ];

    test('nombre completo con marca encuentra el ítem tal cual se ve', () {
      final results = _search(glocks, 'GLOCK Pistola Glock 19 gen 5 FS');
      expect(results.map((p) => p.id), ['g19g5']);
    });

    test('el nombre sin repetir la marca no se rompe', () {
      final results = _search(glocks, 'Pistola Glock 19 gen 5 FS');
      expect(results.map((p) => p.id), ['g19g5']);
    });

    test('palabras no contiguas: "glock fs" cruza campos', () {
      final results = _search(glocks, 'glock fs');
      // Solo los Glock con FS; NO la Bull Armory AXE FS PRO.
      expect(results.map((p) => p.id).toSet(), {'g17', 'g19g5'});
    });

    test('orden invertido: "thunder bersa" == "bersa thunder"', () {
      final bersas = [
        _arma(id: 'b1', marca: 'Bersa', modelo: 'Thunder 9 Pro'),
        _arma(id: 'b2', marca: 'Bersa', modelo: 'Thunder 380'),
        _arma(id: 'b3', marca: 'Bersa', modelo: 'TPR9'),
        _arma(id: 'g', marca: 'Glock', modelo: 'Pistola Glock 19'),
      ];
      final invertido = _search(bersas, 'thunder bersa').map((p) => p.id).toSet();
      final directo = _search(bersas, 'bersa thunder').map((p) => p.id).toSet();
      expect(invertido, {'b1', 'b2'});
      expect(invertido, directo);
    });

    test('"municion" NO devuelve medio catálogo (no envenena por descripción)',
        () {
      final catalog = [
        // Nombrados/marca munición: entran por pasada fuerte.
        _municion(id: 'm1', marca: 'Municiones ABC', codigo: 'MUN-1'),
        _municion(id: 'm2', marca: 'Fabrica', codigo: 'MUNICION-2'),
        // Estos SOLO tienen "municiones" en el texto legal RENAR.
        _arma(id: 'a1', marca: 'Glock', modelo: 'Pistola Glock 19'),
        _arma(id: 'a2', marca: 'Bersa', modelo: 'Thunder 9'),
        _arma(id: 'a3', marca: 'Taurus', modelo: 'G3C'),
      ];
      final results = _search(catalog, 'municion');
      expect(results.map((p) => p.id).toSet(), {'m1', 'm2'});
    });

    group('grafías de calibre 9mm', () {
      final calibres = [
        _municion(id: 'c1', marca: 'A', codigo: 'C1', calibre: '9mm'),
        _municion(id: 'c2', marca: 'B', codigo: 'C2', calibre: '9 mm'),
        _municion(id: 'c3', marca: 'C', codigo: 'C3', calibre: '9x19 MM'),
        _municion(id: 'c4', marca: 'D', codigo: 'C4', calibre: '.45 acp'),
      ];

      test('"9mm" abarca 9mm, 9 mm y 9x19', () {
        final ids = _search(calibres, '9mm').map((p) => p.id).toSet();
        expect(ids, {'c1', 'c2', 'c3'});
      });

      test('"9 mm" (dos palabras) es consistente con "9mm"', () {
        final ids = _search(calibres, '9 mm').map((p) => p.id).toSet();
        expect(ids, {'c1', 'c2', 'c3'});
      });

      test('"9x19" alcanza 9mm vía sinónimo', () {
        final ids = _search(calibres, '9x19').map((p) => p.id).toSet();
        expect(ids, {'c1', 'c2', 'c3'});
      });

      test('"45acp" encuentra ".45 acp" y ".45Acp"', () {
        final catalog = [
          ...calibres,
          _municion(id: 'c5', marca: 'E', codigo: 'C5', calibre: '.45Acp'),
        ];
        final ids = _search(catalog, '45acp').map((p) => p.id).toSet();
        expect(ids, {'c4', 'c5'});
      });
    });

    test('"3006" encuentra "30-06 SPRG"', () {
      final catalog = [
        _municion(id: 'r1', marca: 'Rem', codigo: 'R1', calibre: '30-06 SPRG'),
        _municion(id: 'r2', marca: 'Rem', codigo: 'R2', calibre: '.308 win'),
      ];
      final ids = _search(catalog, '3006').map((p) => p.id).toSet();
      expect(ids, {'r1'});
    });

    test('respaldo por descripción solo cuando la pasada fuerte da cero', () {
      final catalog = [
        _arma(
          id: 'red',
          marca: 'Glock',
          modelo: 'Pistola Glock 19',
          descripcion: 'Incluye red dot Holosun 507C montado en picatinny.',
        ),
        _arma(id: 'plain', marca: 'Bersa', modelo: 'Thunder 9'),
      ];
      // "holosun" no vive en el índice principal: entra por respaldo.
      expect(_search(catalog, 'holosun').map((p) => p.id), ['red']);
      // Con resultados fuertes, el respaldo no agrega ruido.
      expect(_search(catalog, 'glock').map((p) => p.id), ['red']);
    });

    test('consulta vacía devuelve todo, ordenado por marca', () {
      final catalog = [
        _arma(id: 'g', marca: 'Glock', modelo: 'Pistola Glock 19'),
        _arma(id: 'b', marca: 'Bersa', modelo: 'Thunder 9'),
        _arma(id: 't', marca: 'Taurus', modelo: 'G3C'),
      ];
      final results = _search(catalog, '   ');
      expect(results.length, 3);
      expect(results.map((p) => p.marca), ['Bersa', 'Glock', 'Taurus']);
    });

    test('consulta sin coincidencias no rompe y devuelve vacío', () {
      final catalog = [_arma(id: 'g', marca: 'Glock', modelo: 'Pistola Glock 19')];
      expect(_search(catalog, 'xyzqw'), isEmpty);
    });
  });

  group('CatalogService.searchIndexFor cachea y se invalida', () {
    test('devuelve la misma instancia hasta que cambia el catálogo', () {
      final catalog = CatalogService();
      final p = _arma(id: 'g', marca: 'Glock', modelo: 'Pistola Glock 19');

      final first = catalog.searchIndexFor(p);
      final second = catalog.searchIndexFor(p);
      expect(identical(first, second), isTrue);

      // notifyListeners (cualquier cambio del catálogo) invalida la caché.
      catalog.notifyListeners();
      final third = catalog.searchIndexFor(p);
      expect(identical(first, third), isFalse);
    });
  });
}
