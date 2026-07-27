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

void main() {
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
