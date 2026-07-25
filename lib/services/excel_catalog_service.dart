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
  /// Columnas que exporta la app (encabezados del template).
  static const headers = [
    'tipo',
    'marca',
    'calibre',
    'modelo',
    'codigo',
    'descripcion',
    'precio_usd',
    'balas_por_caja',
    'stock',
    'balas_total',
    'stock_inicial',
    'vendido',
  ];

  /// Mapea encabezados libres (CCI, mayúsculas, acentos) a claves canónicas.
  static String? _canonicalHeader(String raw) {
    final h = raw
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    switch (h) {
      case 'tipo':
        return 'tipo';
      case 'marca':
        return 'marca';
      case 'calibre':
      case 'calib':
        return 'calibre';
      case 'modelo':
        return 'modelo';
      case 'codigo':
      case 'code':
      case 'cod':
        return 'codigo';
      case 'descripcion':
      case 'detalle':
      case 'descripcion interna':
        return 'descripcion';
      case 'precio_usd':
      case 'precio usd':
      case 'precio':
      case 'precio (usd)':
      case 'precio u\$s':
      case 'precio us\$':
        return 'precio_usd';
      case 'balas_por_caja':
      case 'balas por caja':
      case 'caja x':
      case 'caja_x':
      case 'cajax':
      case 'balas/caja':
      case 'x caja':
        return 'balas_por_caja';
      case 'stock':
      case 'cajas':
      case 'stock_cajas':
      case 'stock cajas':
      case 'total de cajas':
      case 'total cajas':
        return 'stock';
      case 'total':
      case 'total_balas':
      case 'total balas':
      case 'balas':
      case 'balas_total':
        return 'total_balas';
      case 'stock_inicial':
      case 'inicial':
        return 'stock_inicial';
      case 'vendido':
        return 'vendido';
      default:
        return null;
    }
  }

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
      final r = row + 1;
      _writeCell(sheet, 0, r, product.type.key);
      _writeCell(sheet, 1, r, product.marca);
      _writeCell(sheet, 2, r, product.calibre);
      _writeCell(sheet, 3, r, product.modelo);
      _writeCell(sheet, 4, r, product.codigo);
      _writeCell(sheet, 5, r, product.descripcion);
      _writeCell(sheet, 6, r, product.precioUsd.toString());
      _writeCell(sheet, 7, r, product.roundsPerBox?.toString() ?? '');
      _writeCell(sheet, 8, r, product.stock?.toString() ?? '');
      _writeCell(sheet, 9, r, product.balasDisponibles?.toString() ?? '');
      _writeCell(sheet, 10, r, product.stockInicial?.toString() ?? '');
      _writeCell(sheet, 11, r, product.unidadesVendidas?.toString() ?? '');
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
      final canonical = _canonicalHeader(_cellText(headerRow[i]));
      if (canonical != null && !columnIndex.containsKey(canonical)) {
        columnIndex[canonical] = i;
      }
    }

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
    this.descripcion = '',
    this.stock,
    this.roundsPerBox,
  });

  final ProductType type;
  final String marca;
  final String calibre;
  final String modelo;
  final String codigo;
  final String descripcion;
  final double precioUsd;

  /// Stock en unidades vendibles: cajas (munición) o unidades (armas).
  final int? stock;

  /// Balas por caja (munición).
  final int? roundsPerBox;

  bool get isMunicion => type == ProductType.municion;

  factory ExcelProductRow.fromMap(Map<String, String> data) {
    // tipo: si falta, se asume munición (planillas CCI son munición).
    final typeKey = data['tipo']?.trim().toLowerCase() ?? '';
    ProductType type;
    switch (typeKey) {
      case '':
      case 'municion':
      case 'munición':
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

    int? roundsPerBox = _parseInt(data['balas_por_caja']);
    if (roundsPerBox != null && roundsPerBox <= 0) roundsPerBox = null;

    int? stock = _parseInt(data['stock']);

    // Munición sin cajas explícitas: derivar cajas de TOTAL balas ÷ balas por caja.
    if (type == ProductType.municion && stock == null && roundsPerBox != null) {
      final totalBalas = _parseInt(data['total_balas']);
      if (totalBalas != null) {
        stock = (totalBalas / roundsPerBox).round();
      }
    }

    return ExcelProductRow(
      type: type,
      marca: data['marca']?.trim() ?? '',
      calibre: data['calibre']?.trim() ?? '',
      modelo: data['modelo']?.trim() ?? '',
      codigo: data['codigo']?.trim() ?? '',
      descripcion: data['descripcion']?.trim() ?? '',
      precioUsd: precio,
      stock: stock,
      roundsPerBox: roundsPerBox,
    );
  }

  static int? _parseInt(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    // Soporta "1.000" o "1,000" como miles.
    final normalized = value.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(normalized) ?? int.tryParse(value);
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
      descripcion: descripcion,
      precioUsd: precioUsd,
      stock: stock,
      stockInicial: stock,
      roundsPerBox: isMunicion ? roundsPerBox : null,
    );
  }
}
