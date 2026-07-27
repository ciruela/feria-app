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
  /// Marca por defecto para munición cuando la planilla no trae columna "marca"
  /// (caso típico: planilla de proveedor CCI). Se puede editar luego por producto.
  static const defaultMunicionBrand = 'CCI';

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
        .replaceAll('\u00a0', ' ') // espacios duros de Excel/CCI
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');

    if (h.isEmpty) return null;
    // Precio: cualquier encabezado que arranque con "precio" (precio, precio
    // usd, precio u$d., etc.).
    if (h.startsWith('precio')) return 'precio_usd';

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

  /// Ubica la fila de encabezados (tolerando filas de título arriba y
  /// encabezados partidos en dos filas, como CAJA + X / PRECIO + U$D.) y
  /// detecta la marca si aparece como "Marca: XXX" en el preámbulo.
  static _HeaderMatch _findHeader(List<List<Data?>> rows) {
    final maxScan = rows.length < 25 ? rows.length : 25;
    _HeaderMatch? best;

    for (var h = 0; h < maxScan; h++) {
      final cols = <String, int>{};
      final above = h > 0 ? rows[h - 1] : const <Data?>[];
      final cur = rows[h];
      final width = cur.length > above.length ? cur.length : above.length;

      for (var i = 0; i < width; i++) {
        final topText = i < above.length ? _cellText(above[i]) : '';
        final curText = i < cur.length ? _cellText(cur[i]) : '';
        final canonical = _canonicalHeader('$topText $curText');
        if (canonical != null && !cols.containsKey(canonical)) {
          cols[canonical] = i;
        }
      }

      final hasIdentity = cols.containsKey('codigo') ||
          cols.containsKey('descripcion') ||
          cols.containsKey('modelo');
      final hasPrice = cols.containsKey('precio_usd');
      if (hasIdentity &&
          hasPrice &&
          (best == null || cols.length > best.columns.length)) {
        best = _HeaderMatch(columns: cols, dataStart: h + 1);
      }
    }

    if (best == null) {
      throw Exception(
        'No encontré los encabezados en el Excel. Necesito una columna de '
        'código/descripción/modelo y una de precio.',
      );
    }
    return best;
  }

  /// Extrae calibre y modelo desde una descripción de munición estilo CCI.
  ///
  /// Ejemplos:
  ///   "C.22 40G LR MINI MAG 1235FPS CCI M.960 (50)" -> (.22 LR, M.960)
  ///   "C.22 30G WMG 2200 FPS VARMINT MAXI-MAG TNT M.63 (50)" -> (.22 Mag, M.63)
  ///   "C.22 40G LR SMALL GAME / SUBSONIC 1050 FPS CCI (100)" -> (.22 LR, 40gr)
  static ({String calibre, String modelo}) parseMunicionDescription(
    String descripcion,
  ) {
    final d = descripcion.toUpperCase().replaceAll('\u00a0', ' ');

    // Calibre: token "C.22", "C.223", "C.9", "C.5.56"...
    var calibre = '';
    final cal = RegExp(r'\bC\.?\s*(\d{1,3}(?:\.\d{1,3})?)').firstMatch(d);
    if (cal != null) {
      calibre = '.${cal.group(1)}';
      // Subtipo rimfire típico del .22.
      if (RegExp(r'\bLR\b').hasMatch(d)) {
        calibre = '$calibre LR';
      } else if (RegExp(r'\bWM[RG]\b').hasMatch(d)) {
        calibre = '$calibre Mag';
      }
    }

    // Modelo: código interno "M.xxx" (requiere el punto para no confundir con
    // palabras como MINI/MAXI/MAG). Si no hay, usamos los grains como etiqueta.
    var modelo = '';
    final m = RegExp(r'\bM\.\s*([A-Z0-9]+)').firstMatch(d);
    if (m != null) {
      modelo = 'M.${m.group(1)}';
    } else {
      final g = RegExp(r'\b(\d{2,3})\s*GR?\b').firstMatch(d);
      if (g != null) modelo = '${g.group(1)}gr';
    }

    return (calibre: calibre, modelo: modelo);
  }

  static String? _detectBrand(List<List<Data?>> rows, int upTo) {
    final re = RegExp(r'marca\s*:\s*(.+)', caseSensitive: false);
    for (var r = 0; r < upTo && r < rows.length; r++) {
      for (final cell in rows[r]) {
        final text = _cellText(cell).replaceAll('\u00a0', ' ').trim();
        final match = re.firstMatch(text);
        if (match != null) {
          final brand = match.group(1)?.trim() ?? '';
          if (brand.isNotEmpty) return brand;
        }
      }
    }
    return null;
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

    // No exigimos "marca"/"calibre" (las planillas de proveedor tipo CCI no las
    // traen). Detectamos la fila de encabezados (que puede estar más abajo o
    // partida en dos filas) y la marca del preámbulo ("Marca: CCI").
    final header = _findHeader(sheet.rows);
    final columnIndex = header.columns;
    final brand = _detectBrand(sheet.rows, header.dataStart);

    final rows = <Map<String, String>>[];

    for (var r = header.dataStart; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty || row.every((cell) => _cellText(cell).trim().isEmpty)) {
        continue;
      }

      final data = <String, String>{};
      for (final entry in columnIndex.entries) {
        final cell = entry.value < row.length ? row[entry.value] : null;
        data[entry.key] = _cellText(cell).replaceAll('\u00a0', ' ').trim();
      }

      // Saltear filas sin ningún identificador (ej. filas de subtotal/total).
      final hasData = (data['codigo']?.isNotEmpty ?? false) ||
          (data['descripcion']?.isNotEmpty ?? false) ||
          (data['modelo']?.isNotEmpty ?? false);
      if (!hasData) continue;

      // Marca detectada en el preámbulo cuando la fila no la trae.
      if (brand != null && (data['marca']?.isEmpty ?? true)) {
        data['marca'] = brand;
      }
      rows.add(data);
    }

    if (rows.isEmpty) {
      throw Exception('No encontré filas de productos debajo de los encabezados.');
    }

    return rows;
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

/// Resultado de ubicar la fila de encabezados: mapa columna->índice y la fila
/// donde arrancan los datos.
class _HeaderMatch {
  const _HeaderMatch({required this.columns, required this.dataStart});

  final Map<String, int> columns;
  final int dataStart;
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

    // Si la planilla no trae marca (típico en munición de proveedor), usamos
    // una por defecto para que el producto sea válido; se puede editar luego.
    var marca = data['marca']?.trim() ?? '';
    if (marca.isEmpty && type == ProductType.municion) {
      marca = ExcelCatalogService.defaultMunicionBrand;
    }

    var calibre = data['calibre']?.trim() ?? '';
    var modelo = data['modelo']?.trim() ?? '';
    final descripcion = data['descripcion']?.trim() ?? '';

    // Munición CCI: los datos vienen empaquetados en la descripción
    // ("C.22 40G LR MINI MAG 1235FPS CCI M.960 (50)"). Extraemos calibre y
    // modelo cuando la planilla no trae esas columnas por separado.
    if (type == ProductType.municion && descripcion.isNotEmpty) {
      final parsed = ExcelCatalogService.parseMunicionDescription(descripcion);
      if (calibre.isEmpty) calibre = parsed.calibre;
      if (modelo.isEmpty) modelo = parsed.modelo;
    }

    return ExcelProductRow(
      type: type,
      marca: marca,
      calibre: calibre,
      modelo: modelo,
      codigo: data['codigo']?.trim() ?? '',
      descripcion: descripcion,
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
