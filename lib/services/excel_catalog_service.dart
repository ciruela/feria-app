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

/// Qué haría cada fila del Excel al importarse.
enum ExcelImportAction { create, update, skip }

/// Fila del Excel ya interpretada, para mostrarla en el preview de importación.
class ExcelImportPreviewRow {
  const ExcelImportPreviewRow({
    required this.row,
    required this.action,
    this.existingId,
  });

  final ExcelProductRow row;
  final ExcelImportAction action;
  final String? existingId;
}

/// Resultado de interpretar un Excel sin escribir nada (para revisar antes).
class ExcelImportPreview {
  const ExcelImportPreview({required this.rows, required this.unreadable});

  final List<ExcelImportPreviewRow> rows;

  /// Filas debajo de los encabezados que no se pudieron interpretar.
  final int unreadable;

  int get toCreate =>
      rows.where((r) => r.action == ExcelImportAction.create).length;
  int get toUpdate =>
      rows.where((r) => r.action == ExcelImportAction.update).length;
  int get toSkip =>
      rows.where((r) => r.action == ExcelImportAction.skip).length;
}

class ExcelCatalogService {
  /// Marca por defecto para munición solo si no hay ninguna pista en la planilla
  /// (columna, preámbulo, hoja o descripción). Caso típico: planilla CCI vieja.
  static const defaultMunicionBrand = 'CCI';

  /// Marcas de munición frecuentes en planillas AR. Orden: más largas primero
  /// para no matchear "BELL" dentro de "SELLIER & BELLOT".
  static const knownMunicionBrands = [
    'SELLIER & BELLOT',
    'SELLIER Y BELLOT',
    'BARNES BULLETS',
    'WINCHESTER',
    'REMINGTON',
    'FEDERAL',
    'HORNADY',
    'MAGTECH',
    'NORMA',
    'ORBEA',
    'AGUILA',
    'NOSLER',
    'SPEER',
    'LAPUA',
    'GECO',
    'ELEY',
    'PPU',
    'CCI',
    'CBC',
    'SK',
    'RD',
  ];

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

  /// Busca una marca conocida en texto libre (título, hoja, descripción).
  static String? inferBrandFromText(String raw) {
    final text = raw.replaceAll('\u00a0', ' ').trim().toUpperCase();
    if (text.isEmpty) return null;
    for (final brand in knownMunicionBrands) {
      final pattern = RegExp(
        '\\b${RegExp.escape(brand)}\\b',
        caseSensitive: false,
      );
      if (pattern.hasMatch(text)) {
        // Canonical: primera palabra con mayúsculas típicas (Orbea, CCI…).
        if (brand == 'SELLIER & BELLOT' || brand == 'SELLIER Y BELLOT') {
          return 'Sellier & Bellot';
        }
        if (brand == 'BARNES BULLETS') return 'Barnes';
        if (brand.length <= 3) return brand; // CCI, PPU, RD, SK, CBC
        return brand[0] + brand.substring(1).toLowerCase();
      }
    }
    return null;
  }

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
    // Precio: flexible (planillas CCI, export propio, armerías).
    if (h.startsWith('precio')) return 'precio_usd';
    if (h == 'usd' ||
        h == 'u\$d' ||
        h == 'u\$s' ||
        h == '\$' ||
        h.startsWith('u\$d') ||
        h.startsWith('u\$s') ||
        h == 'importe' ||
        h == 'valor' ||
        h.contains('p. unit') ||
        h.contains('p unit') ||
        h == 'punit' ||
        h == 'punitario') {
      return 'precio_usd';
    }

    switch (h) {
      case 'tipo':
        return 'tipo';
      case 'marca':
      case 'brand':
      case 'fabricante':
      case 'maker':
      case 'proveedor':
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
      case 'producto':
      case 'articulo':
      case 'item':
      case 'nombre':
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

  static void _registerHeader(
    String raw,
    Map<String, int> cols,
    int columnIndex,
  ) {
    final canonical = _canonicalHeader(raw);
    if (canonical != null && !cols.containsKey(canonical)) {
      cols[canonical] = columnIndex;
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
      // Acumula encabezados de todas las filas de preámbulo hasta [h]
      // (PPU y similares: U$D en fila 0, Código/Descripción en fila 2).
      for (var r = 0; r <= h; r++) {
        final above = r > 0 ? rows[r - 1] : const <Data?>[];
        final cur = rows[r];
        final width = cur.length > above.length ? cur.length : above.length;

        for (var i = 0; i < width; i++) {
          final topText = i < above.length ? _cellText(above[i]) : '';
          final curText = i < cur.length ? _cellText(cur[i]) : '';
          _registerHeader(curText, cols, i);
          _registerHeader(topText, cols, i);
          _registerHeader('$topText $curText', cols, i);
          if (topText.isNotEmpty && curText.isNotEmpty) {
            _registerHeader('$topText$curText', cols, i);
          }
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
        'No encontré los encabezados en el Excel. Necesito al menos una columna '
        'de código, descripción o modelo, y otra de precio (precio, USD, '
        'importe o p. unit). Si es .xls o CSV, guardalo como .xlsx e intentá de nuevo.',
      );
    }
    return best;
  }

  /// Extrae calibre y modelo desde una descripción de munición estilo CCI.
  ///
  /// Ejemplos:
  ///   "C.22 40G LR MINI MAG 1235FPS CCI M.960 (50)" -> (.22 LR, M.960)
  ///   "C.22 30G WMG 2200 FPS VARMINT MAXI-MAG TNT M.63 (50)" -> (.22 Mag, M.63)
  ///   "C.22 40G LR SMALL GAME / SUBSONIC 1050 FPS CCI (100)" -> (.22 LR, '')
  ///
  /// El "40G" es el peso de la punta (grains) y se expone aparte vía
  /// [Product.granos], no como modelo.
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
    // palabras como MINI/MAXI/MAG). Si no hay, queda vacío.
    var modelo = '';
    final m = RegExp(r'\bM\.\s*([A-Z0-9]+)').firstMatch(d);
    if (m != null) modelo = 'M.${m.group(1)}';

    return (calibre: calibre, modelo: modelo);
  }

  static String? _detectBrand(
    List<List<Data?>> rows,
    int upTo, {
    String? sheetName,
  }) {
    final withColon = RegExp(r'marca\s*:\s*(.+)', caseSensitive: false);
    final withoutColon = RegExp(r'^marca\s+(.+)$', caseSensitive: false);
    // 1) Explicit "Marca: Orbea" / "MARCA PPU" in the preamble.
    for (var r = 0; r < upTo && r < rows.length; r++) {
      for (final cell in rows[r]) {
        final text = _cellText(cell).replaceAll('\u00a0', ' ').trim();
        final match = withColon.firstMatch(text) ??
            withoutColon.firstMatch(text);
        if (match != null) {
          final brand = match.group(1)?.trim() ?? '';
          if (brand.isNotEmpty) return brand;
        }
      }
    }
    // 2) Título / celda con marca conocida ("LISTADO ORBEA", "ORBEA", etc.).
    for (var r = 0; r < upTo && r < rows.length; r++) {
      for (final cell in rows[r]) {
        final inferred = inferBrandFromText(_cellText(cell));
        if (inferred != null) return inferred;
      }
    }
    // 3) Nombre de la hoja del Excel.
    return inferBrandFromText(sheetName ?? '');
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

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    if (sheet.rows.isEmpty) {
      throw Exception('El Excel no tiene filas');
    }

    // No exigimos "marca"/"calibre" (las planillas de proveedor tipo CCI no las
    // traen). Detectamos la fila de encabezados (que puede estar más abajo o
    // partida en dos filas) y la marca del preámbulo / hoja / título.
    final header = _findHeader(sheet.rows);
    final columnIndex = header.columns;
    final brand = _detectBrand(
      sheet.rows,
      header.dataStart,
      sheetName: sheetName,
    );

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
    // Preferir el valor tipado: toString() de CellValue a veces envuelve el número.
    if (value is DoubleCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is TextCellValue) return value.value.toString();
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

    final precio = _parsePrice(data['precio_usd']);

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

    var calibre = data['calibre']?.trim() ?? '';
    var modelo = data['modelo']?.trim() ?? '';
    final descripcion = data['descripcion']?.trim() ?? '';

    // Marca: columna → pista en la descripción → CCI solo como último recurso.
    var marca = data['marca']?.trim() ?? '';
    if (marca.isEmpty && type == ProductType.municion) {
      marca = ExcelCatalogService.inferBrandFromText(descripcion) ??
          ExcelCatalogService.defaultMunicionBrand;
    }

    // Munición estilo proveedor: datos empaquetados en la descripción
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

  /// Precio USD: soporta "12.5", "12,50", "1.234,56", "U\$D 12", etc.
  static double _parsePrice(String? raw) {
    var value = (raw ?? '')
        .replaceAll('\u00a0', ' ')
        .trim()
        .replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (value.isEmpty) return 0;

    final hasComma = value.contains(',');
    final hasDot = value.contains('.');
    if (hasComma && hasDot) {
      // El último separador es el decimal (AR: 1.234,56 / US: 1,234.56).
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (hasComma) {
      value = value.replaceAll(',', '.');
    }

    return double.tryParse(value) ?? 0;
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
