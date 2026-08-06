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

Uint8List _orbeaReportBytes() {
  // Planilla Orbea típica: título con la marca (sin "Marca:") y descripción
  // estilo proveedor. Antes caía en CCI por el default.
  final excel = Excel.createExcel();
  final name = excel.sheets.keys.first;
  excel.rename(name, 'Orbea');
  final s = excel['Orbea'];
  void put(int c, int r, String v) => s
      .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
      .value = TextCellValue(v);

  put(0, 0, 'LISTADO ORBEA');
  put(0, 1, 'Código');
  put(1, 1, 'Descripción');
  put(2, 1, 'CAJA X');
  put(3, 1, 'CAJAS');
  put(4, 1, 'PRECIO');
  put(0, 2, '1122803');
  put(1, 2, 'C.12 28G ORBEA (25)');
  put(2, 2, '25');
  put(3, 2, '19');
  put(4, 2, '17');
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
    test('munición sin marca usa CCI por defecto', () {
      final row = ExcelProductRow.fromMap({
        'codigo': '0034',
        'descripcion': '22LR 40gr',
        'balas_por_caja': '50',
        'stock': '10',
        'precio_usd': '8.5',
      });
      expect(row.type, ProductType.municion);
      expect(row.marca, ExcelCatalogService.defaultMunicionBrand);
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

    test('planilla Orbea: detecta marca del título/hoja (no fuerza CCI)', () {
      final rows = service.parseRows(_orbeaReportBytes());
      expect(rows.length, 1);
      expect(rows.first['codigo'], '1122803');
      expect(rows.first['marca'], 'Orbea');
      final row = ExcelProductRow.fromMap(rows.first);
      expect(row.marca, 'Orbea');
      expect(row.stock, 19);
      expect(row.precioUsd, 17);
    });
  });

  group('inferBrandFromText', () {
    test('encuentra Orbea en título o descripción', () {
      expect(
        ExcelCatalogService.inferBrandFromText('LISTADO ORBEA'),
        'Orbea',
      );
      expect(
        ExcelCatalogService.inferBrandFromText('C.12 28G ORBEA (25)'),
        'Orbea',
      );
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
