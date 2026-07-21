import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/product.dart';

class ExcelImportResult {
  const ExcelImportResult({
    required this.updated,
    required this.added,
    required this.skipped,
  });

  final int updated;
  final int added;
  final int skipped;
}

class ExcelCatalogService {
  static const headers = [
    'tipo',
    'marca',
    'calibre',
    'modelo',
    'codigo',
    'precio_usd',
    'stock',
  ];

  Uint8List exportProducts(List<Product> products) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Catalogo');
    final sheet = excel['Catalogo'];

    for (var col = 0; col < headers.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = TextCellValue(headers[col]);
    }

    for (var row = 0; row < products.length; row++) {
      final product = products[row];
      _writeCell(sheet, 0, row + 1, product.type.key);
      _writeCell(sheet, 1, row + 1, product.marca);
      _writeCell(sheet, 2, row + 1, product.calibre);
      _writeCell(sheet, 3, row + 1, product.modelo);
      _writeCell(sheet, 4, row + 1, product.codigo);
      _writeCell(sheet, 5, row + 1, product.precioUsd.toString());
      _writeCell(
        sheet,
        6,
        row + 1,
        product.stock?.toString() ?? '',
      );
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el Excel');
    }
    return Uint8List.fromList(bytes);
  }

  List<Map<String, String>> parseRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('El Excel está vacío');
    }

    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) {
      throw Exception('El Excel no tiene filas');
    }

    final headerRow = sheet.rows.first;
    final columnIndex = <String, int>{};

    for (var i = 0; i < headerRow.length; i++) {
      final header = _cellText(headerRow[i]).trim().toLowerCase();
      if (header.isNotEmpty) {
        columnIndex[header] = i;
      }
    }

    _requireColumn(columnIndex, 'tipo');
    _requireColumn(columnIndex, 'marca');
    _requireColumn(columnIndex, 'calibre');

    final rows = <Map<String, String>>[];

    for (var r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty || row.every((cell) => _cellText(cell).trim().isEmpty)) {
        continue;
      }

      final data = <String, String>{};
      for (final entry in columnIndex.entries) {
        final cell = entry.value < row.length ? row[entry.value] : null;
        data[entry.key] = _cellText(cell).trim();
      }

      if (data['marca']?.isEmpty ?? true) continue;
      rows.add(data);
    }

    return rows;
  }

  static void _requireColumn(Map<String, int> columns, String name) {
    if (!columns.containsKey(name)) {
      throw Exception('Falta la columna "$name" en el Excel');
    }
  }

  static void _writeCell(
    Sheet sheet,
    int column,
    int row,
    String value,
  ) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
        .value = TextCellValue(value);
  }

  static String _cellText(Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString();
  }
}

class ExcelProductRow {
  ExcelProductRow({
    required this.type,
    required this.marca,
    required this.calibre,
    required this.modelo,
    required this.codigo,
    required this.precioUsd,
    this.stock,
  });

  final ProductType type;
  final String marca;
  final String calibre;
  final String modelo;
  final String codigo;
  final double precioUsd;
  final int? stock;

  factory ExcelProductRow.fromMap(Map<String, String> data) {
    final typeKey = data['tipo']?.trim() ?? '';
    ProductType type;
    switch (typeKey) {
      case 'municion':
        type = ProductType.municion;
      case 'arma_corta':
        type = ProductType.armaCorta;
      case 'arma_larga':
        type = ProductType.armaLarga;
      default:
        throw FormatException('Tipo inválido: $typeKey');
    }

    final precioRaw = data['precio_usd']?.replaceAll(',', '.') ?? '0';
    final precio = double.tryParse(precioRaw) ?? 0;

    int? stock;
    final stockRaw = data['stock']?.trim() ?? '';
    if (stockRaw.isNotEmpty) {
      stock = int.tryParse(stockRaw);
    }

    return ExcelProductRow(
      type: type,
      marca: data['marca']?.trim() ?? '',
      calibre: data['calibre']?.trim() ?? '',
      modelo: data['modelo']?.trim() ?? '',
      codigo: data['codigo']?.trim() ?? '',
      precioUsd: precio,
      stock: stock,
    );
  }

  Product toNewProduct(int index) {
    final slug = codigo.isNotEmpty
        ? codigo
        : modelo.isNotEmpty
            ? modelo
            : 'item-$index';

    return Product(
      id: '${type.key}-${slug.toLowerCase().replaceAll(' ', '-')}-$index',
      type: type,
      marca: marca,
      calibre: calibre,
      codigo: codigo.isNotEmpty ? codigo : slug,
      modelo: modelo,
      precioUsd: precioUsd,
      stock: stock,
    );
  }
}
