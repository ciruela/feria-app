import 'dart:typed_data';

import 'package:app_feria/models/product.dart';
import 'package:app_feria/services/excel_catalog_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _sheetBytes(List<String> headers, List<List<Object>> rows) {
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Hoja');
  final sheet = excel['Hoja'];
  for (var c = 0; c < headers.length; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue(headers[c]);
  }
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = TextCellValue(rows[r][c].toString());
    }
  }
  return Uint8List.fromList(excel.encode()!);
}

Uint8List _cciReportBytes() {
  // Reproduce la planilla real de CCI: filas de título, "Marca: CCI" y un
  // encabezado partido en dos filas (CAJA + X, PRECIO + U$D.).
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Hoja');
  final s = excel['Hoja'];
  void put(int c, int r, String v) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
      .value = TextCellValue(v);

  put(1, 0, 'Informe de stock por marca');
  put(0, 1, 'Marca: CCI');
  // Encabezado fila 3 (índice 2) + fila 4 (índice 3).
  put(2, 2, 'TOTAL');
  put(3, 2, 'CAJA ');
  put(4, 2, 'CAJAS');
  put(5, 2, 'PRECIO');
  put(0, 3, 'Código');
  put(1, 3, 'Descripción');
  put(3, 3, 'X');
  put(5, 3, 'U\$D.');
  // Datos (índice 4+).
  put(0, 4, '20732');
  put(1, 4, 'C.22 30G LR VARMIT V-MAX (50)');
  put(2, 4, '800');
  put(3, 4, '50');
  put(4, 4, '16');
  put(5, 4, '75');
  put(0, 5, '20824');
  put(1, 5, 'C.22 30G WMG (50)');
  put(2, 5, '4950');
  put(3, 5, '50');
  put(5, 5, '58');
  return Uint8List.fromList(excel.encode()!);
}

Uint8List _ppuReportBytes() {
  // PPU real: encabezado de precio (U$D) en fila 0, fila vacía, identidad en fila 2.
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Hoja');
  final s = excel['Hoja'];
  void put(int c, int r, String v) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
      .value = TextCellValue(v);

  put(0, 0, 'MARCA PPU');
  put(6, 0, 'CAJA ');
  put(7, 0, 'CAJAS');
  put(8, 0, 'U\$D');
  put(0, 2, 'Código');
  put(1, 2, 'Descripción');
  put(4, 2, 'TOTAL');
  put(6, 2, 'X');
  put(0, 3, '9684');
  put(1, 3, 'C.243 WIN 100GR SP RIFLE LINE PPU');
  put(4, 3, '380');
  put(6, 3, '20');
  put(7, 3, 'E4/G4');
  put(8, 3, '60');
  return Uint8List.fromList(excel.encode()!);
}

Uint8List _rdReportBytes() {
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Hoja');
  final s = excel['Hoja'];
  void put(int c, int r, String v) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
      .value = TextCellValue(v);

  put(0, 0, 'MARCA: RD');
  put(0, 1, 'Código');
  put(1, 1, 'Descripción');
  put(2, 1, 'TOTAL ');
  put(3, 1, 'CAJA X ');
  put(4, 1, 'CAJAS');
  put(5, 1, '\$');
  put(0, 2, '13040');
  put(1, 2, 'FULMINANTES SMALL PISTOL C.9');
  put(2, 2, '79000');
  put(3, 2, '1000');
  put(5, 2, '65000');
  return Uint8List.fromList(excel.encode()!);
}

/// Planilla de proveedor genérica: título = marca (celda arriba), sin columna Marca.
Uint8List _brandTitleReportBytes(String brandTitle) {
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Hoja');
  final s = excel['Hoja'];
  void put(int c, int r, String v) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
      .value = TextCellValue(v);

  put(0, 0, brandTitle);
  put(0, 1, 'Código');
  put(1, 1, 'Descripción');
  put(2, 1, 'TOTAL');
  put(3, 1, 'CAJA X');
  put(4, 1, 'CAJAS');
  put(5, 1, 'U\$D');
  put(0, 2, '1122803');
  put(1, 2, 'C.12 28G M3 CARTUCHO $brandTitle (25)');
  put(2, 2, '25');
  put(3, 2, '25');
  put(4, 2, '1');
  put(5, 2, '17');
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  group('ExcelCatalogService.parseRows (reporte CCI real)', () {
    test('salta preámbulo, une encabezado partido y detecta marca', () {
      final rows = ExcelCatalogService().parseRows(_cciReportBytes());
      expect(rows.length, 2);
      final first = rows.first;
      expect(first['codigo'], '20732');
      expect(first['balas_por_caja'], '50');
      expect(first['total_balas'], '800');
      expect(first['stock'], '16');
      expect(first['precio_usd'], '75');
      expect(first['marca'], 'CCI'); // detectada del preámbulo

      final row = ExcelProductRow.fromMap(first);
      expect(row.marca, 'CCI');
      expect(row.stock, 16);
      expect(row.roundsPerBox, 50);
      expect(row.precioUsd, 75);
    });

    test('deriva cajas cuando la columna CAJAS viene vacía', () {
      final rows = ExcelCatalogService().parseRows(_cciReportBytes());
      final second = ExcelProductRow.fromMap(rows[1]);
      expect(second.stock, 99); // 4950 / 50
    });
  });

  group('parseMunicionDescription (CCI)', () {
    ({String calibre, String modelo}) p(String d) =>
        ExcelCatalogService.parseMunicionDescription(d);

    test('extrae calibre .22 LR y modelo M.xxx', () {
      final r = p('C.22 40G LR 710 TARGET QUIET FPS  CCI  M.960 (50)');
      expect(r.calibre, '.22 LR');
      expect(r.modelo, 'M.960');
    });

    test('detecta magnum por WMG', () {
      final r = p('C.22 30G WMG 2200 FPS VARMINT MAXI-MAG TNT M.63  (50)');
      expect(r.calibre, '.22 Mag');
      expect(r.modelo, 'M.63');
    });

    test('sin M.xxx el modelo queda vacío (los grains van aparte)', () {
      final r = p('C.22 32G LR VARMINT 1640FPS CCI (50)');
      expect(r.calibre, '.22 LR');
      expect(r.modelo, '');
    });

    test('no confunde MINI MAG con magnum', () {
      final r = p('C.22 36G LR VARMINT / MINI MAG 1260FPS  CCI MINI NAG (100)');
      expect(r.calibre, '.22 LR');
      expect(r.modelo, '');
    });

    test('modelo con sufijo alfanumérico (960CC)', () {
      final r = p('C.22 32G LR DEFENSE M.960CC CCI (50)');
      expect(r.calibre, '.22 LR');
      expect(r.modelo, 'M.960CC');
    });

    test('fromMap puebla calibre/modelo desde la descripción', () {
      final row = ExcelProductRow.fromMap({
        'codigo': '20732',
        'marca': 'CCI',
        'descripcion': 'C.22 30G LR VARMIT V-MAX 30GR 2200 FPS CCI M.73 (50)',
        'balas_por_caja': '50',
        'total_balas': '800',
        'precio_usd': '75',
      });
      expect(row.calibre, '.22 LR');
      expect(row.modelo, 'M.73');
      expect(row.marca, 'CCI');
    });
  });

  group('ExcelProductRow.fromMap (CCI)', () {
    test('munición sin marca queda vacía (fail-closed)', () {
      final row = ExcelProductRow.fromMap({
        'codigo': '0034',
        'descripcion': '22LR 40gr',
        'balas_por_caja': '50',
        'stock': '10',
        'precio_usd': '8.5',
      });
      expect(row.type, ProductType.municion);
      expect(row.marca, isEmpty);
      expect(row.roundsPerBox, 50);
      expect(row.stock, 10);
      expect(row.precioUsd, 8.5);
    });

    test('deriva cajas desde total de balas', () {
      final row = ExcelProductRow.fromMap({
        'codigo': '9999',
        'balas_por_caja': '50',
        'total_balas': '500',
        'precio_usd': '10',
      });
      expect(row.stock, 10); // 500 / 50
    });

    test('respeta cajas explícitas por sobre el total', () {
      final row = ExcelProductRow.fromMap({
        'codigo': '1',
        'balas_por_caja': '50',
        'stock': '3',
        'total_balas': '500',
        'precio_usd': '10',
      });
      expect(row.stock, 3);
    });
  });

  group('ExcelCatalogService.parseRows', () {
    final service = ExcelCatalogService();

    test('lee planilla estilo CCI (sin marca/calibre)', () {
      final bytes = _sheetBytes(
        ['CODIGO', 'DESCRIPCION', 'CAJA X', 'TOTAL', 'Total de cajas', 'PRECIO'],
        [
          ['0034', '22LR 40gr', 50, 500, 10, '8.5'],
          ['0035', '9mm 124gr', 50, 1000, 20, '15'],
        ],
      );
      final rows = service.parseRows(bytes);
      expect(rows.length, 2);
      expect(rows.first['codigo'], '0034');
      expect(rows.first['balas_por_caja'], '50');
      expect(rows.first['stock'], '10');
      expect(rows.first['precio_usd'], '8.5');
    });

    test('saltea filas sin identificador', () {
      final bytes = _sheetBytes(
        ['CODIGO', 'PRECIO'],
        [
          ['0034', '8.5'],
          ['', ''],
        ],
      );
      expect(service.parseRows(bytes).length, 1);
    });

    test('falla si no hay columna de precio', () {
      final bytes = _sheetBytes(
        ['CODIGO', 'DESCRIPCION'],
        [
          ['0034', 'algo'],
        ],
      );
      expect(() => service.parseRows(bytes), throwsException);
    });

    test('falla si no hay ninguna columna identificadora', () {
      final bytes = _sheetBytes(
        ['PRECIO', 'CAJA X'],
        [
          ['8.5', '50'],
        ],
      );
      expect(() => service.parseRows(bytes), throwsException);
    });

    test('detecta encabezado en fila actual aunque la fila de arriba tenga texto', () {
      final excel = Excel.createExcel();
      final name = excel.sheets.keys.first;
      excel.rename(name, 'Hoja');
      final s = excel['Hoja'];
      void put(int c, int r, String v) => s
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(v);

      put(0, 0, 'Marca: CCI');
      put(0, 1, 'Código');
      put(1, 1, 'Descripción');
      put(2, 1, 'USD');
      put(0, 2, '100');
      put(1, 2, '22LR 40gr');
      put(2, 2, '8.5');

      final rows = service.parseRows(Uint8List.fromList(excel.encode()!));
      expect(rows.length, 1);
      expect(rows.first['codigo'], '100');
      expect(rows.first['precio_usd'], '8.5');
    });

    test('acepta IMPORTE y P. UNIT como columna de precio', () {
      for (final priceHeader in ['IMPORTE', 'P. UNIT']) {
        final bytes = _sheetBytes(
          ['CODIGO', 'PRODUCTO', priceHeader],
          [
            ['0034', '22LR 40gr', '8.5'],
          ],
        );
        final rows = service.parseRows(bytes);
        expect(rows.single['precio_usd'], '8.5', reason: priceHeader);
      }
    });

    test('planilla PPU: encabezado partido con fila vacía en el medio', () {
      final rows = service.parseRows(_ppuReportBytes());
      expect(rows.length, 1);
      expect(rows.first['codigo'], '9684');
      expect(rows.first['precio_usd'], '60');
      expect(rows.first['marca'], 'PPU');
    });

    test('planilla RD: columna \$ como precio', () {
      final rows = service.parseRows(_rdReportBytes());
      expect(rows.length, 1);
      expect(rows.first['codigo'], '13040');
      expect(rows.first['precio_usd'], '65000');
      expect(rows.first['marca'], 'RD');
    });

    test('detecta marca desde fila título (ORBEA, Aguila, etc.)', () {
      for (final brand in ['ORBEA', 'Aguila', 'ACME']) {
        final rows = service.parseRows(_brandTitleReportBytes(brand));
        expect(rows.single['marca'], brand, reason: brand);
        expect(ExcelProductRow.fromMap(rows.single).marca, brand);
      }
    });

    test('detecta marca desde LISTADO + nombre', () {
      final rows = service.parseRows(_brandTitleReportBytes('LISTADO ORBEA'));
      expect(rows.single['marca'], 'ORBEA');
    });
  });

  group('normalizeBrandCandidate', () {
    test('acepta títulos de marca y rechaza informes', () {
      expect(ExcelCatalogService.normalizeBrandCandidate('ORBEA'), 'ORBEA');
      expect(
        ExcelCatalogService.normalizeBrandCandidate('LISTADO ORBEA'),
        'ORBEA',
      );
      expect(
        ExcelCatalogService.normalizeBrandCandidate('Informe de stock por marca'),
        isNull,
      );
      expect(ExcelCatalogService.normalizeBrandCandidate('Hoja1'), isNull);
    });
  });

  group('ExcelCatalogService.parseRows multi-hoja', () {
    test('lee productos de todas las hojas con su marca', () {
      final excel = Excel.createExcel();
      final first = excel.sheets.keys.first;
      excel.rename(first, 'ORBEA');
      final orbea = excel['ORBEA'];
      void put(Sheet s, int c, int r, String v) => s
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(v);

      put(orbea, 0, 0, 'ORBEA');
      put(orbea, 0, 1, 'Código');
      put(orbea, 1, 1, 'Descripción');
      put(orbea, 2, 1, 'PRECIO');
      put(orbea, 0, 2, '1111');
      put(orbea, 1, 2, 'C.12 ORBEA (25)');
      put(orbea, 2, 2, '10');

      excel.copy('ORBEA', 'Aguila');
      // copy may duplicate; rewrite Aguila sheet cleanly
      final aguila = excel['Aguila'];
      // Clear by overwriting header/data
      put(aguila, 0, 0, 'Aguila');
      put(aguila, 0, 1, 'Código');
      put(aguila, 1, 1, 'Descripción');
      put(aguila, 2, 1, 'PRECIO');
      put(aguila, 0, 2, '9999');
      put(aguila, 1, 2, 'C.22 AGUILA (50)');
      put(aguila, 2, 2, '12');

      final rows = ExcelCatalogService()
          .parseRows(Uint8List.fromList(excel.encode()!));
      expect(rows.length, greaterThanOrEqualTo(2));
      final marcas = rows.map((r) => r['marca']).toSet();
      expect(marcas.contains('ORBEA') || marcas.contains('Orbea'), isTrue);
      expect(
        marcas.any((m) => (m ?? '').toLowerCase() == 'aguila'),
        isTrue,
      );
    });
  });

  group('precios fijos (Urban)', () {
    test('parsea columnas de precios fijos del Excel limpio', () {
      final bytes = _sheetBytes(
        [
          'tipo', 'marca', 'calibre', 'modelo', 'codigo', 'descripcion',
          'precio_usd', 'stock',
          'efectivo_ars', 'efectivo_usd', 'tarjeta_ars',
          'cuota3_ars', 'cuota6_ars', 'cuota12_ars',
        ],
        [
          [
            'arma_larga', 'Sibian Armory', '.223', 'FA15', 'SIBIANFA15223',
            'Carabina', '3500', '10',
            '5495000', '3500', '5659850',
            '2058864.77', '1100463.50', '644232.43',
          ],
        ],
      );

      final rows = ExcelCatalogService().parseRows(bytes);
      final row = ExcelProductRow.fromMap(rows.single);

      expect(row.type, ProductType.armaLarga);
      expect(row.codigo, 'SIBIANFA15223');
      final fixed = row.fixedPrices;
      expect(fixed, isNotNull);
      expect(fixed!.efectivoArs, 5495000);
      expect(fixed.efectivoUsd, 3500);
      expect(fixed.tarjetaArs, 5659850);
      expect(fixed.cuota3Ars, closeTo(2058864.77, 0.01));
      expect(fixed.cuota6Ars, closeTo(1100463.50, 0.01));
      expect(fixed.cuota12Ars, closeTo(644232.43, 0.01));

      final product = row.toNewProduct(0);
      expect(product.hasFixedPrices, isTrue);
      // Roundtrip JSON (caché local / Supabase).
      final restored = Product.fromJson(product.toJson());
      expect(restored.fixedPrices?.efectivoArs, 5495000);
      expect(restored.fixedPrices?.cuota12Ars, closeTo(644232.43, 0.01));
    });

    test('sin columnas de precios fijos, fixedPrices queda null', () {
      final bytes = _sheetBytes(
        ['tipo', 'marca', 'calibre', 'modelo', 'codigo', 'precio_usd', 'stock'],
        [
          ['arma_corta', 'Glock', '9', 'G17', 'G17', '600', '5'],
        ],
      );
      final row = ExcelProductRow.fromMap(
        ExcelCatalogService().parseRows(bytes).single,
      );
      expect(row.fixedPrices, isNull);
    });
  });

  group('export/import roundtrip', () {
    test('lo exportado se puede volver a parsear', () {
      const products = [
        Product(
          id: 'municion-0034-1',
          type: ProductType.municion,
          marca: 'CCI',
          calibre: '22LR',
          codigo: '0034',
          precioUsd: 8.5,
          stock: 10,
          roundsPerBox: 50,
        ),
      ];
      final bytes = ExcelCatalogService().exportProducts(products);
      final rows = ExcelCatalogService().parseRows(bytes);
      expect(rows.single['codigo'], '0034');
      expect(rows.single['marca'], 'CCI');
    });
  });
}
