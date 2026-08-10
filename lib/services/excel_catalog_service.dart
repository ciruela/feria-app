import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/product.dart';
import '../models/product_prices.dart';

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
    this.warnings = const [],
    this.existingStock,
    this.existingMarca,
  });

  final ExcelProductRow row;
  final ExcelImportAction action;
  final String? existingId;
  final List<String> warnings;
  final int? existingStock;
  final String? existingMarca;
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

  int get withWarnings =>
      rows.where((r) => r.warnings.isNotEmpty).length;
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

  /// Normaliza un candidato a marca leído del Excel (título, hoja, "Marca: X").
  /// Devuelve null si el texto parece un encabezado/informe, no una marca.
  static String? normalizeBrandCandidate(String raw) {
    var t = raw.replaceAll('\u00a0', ' ').trim();
    if (t.isEmpty) return null;

    final listado = RegExp(
      r'^(?:listado|lista|cat[aá]logo)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(t);
    if (listado != null) {
      t = listado.group(1)!.trim();
    }

    final lower = t.toLowerCase();
    if (lower.contains('informe') ||
        lower.contains('stock por') ||
        lower.contains('encabezado') ||
        lower.contains('por marca') ||
        lower.startsWith('precio') ||
        lower == 'total' ||
        lower == 'cajas' ||
        lower == 'descripcion' ||
        lower == 'descripción') {
      return null;
    }

    if (t.length > 40) return null;
    if (_canonicalHeader(t) != null) return null;
    if (RegExp(r'^[\d.,\s\$]+$').hasMatch(t)) return null;
    if (RegExp(
      r'^(hoja\s*\d*|sheet\s*\d*|catalogo|catálogo)$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return null;
    }
    // Marcas suelen ser 1–4 palabras ("Sellier & Bellot").
    if (t.split(RegExp(r'\s+')).length > 4) return null;
    return t;
  }

  /// Resuelve el [ProductType] de una fila:
  /// 1) columna `tipo` explícita (`accesorios`, `municion`, `arma_corta`,
  ///    `arma_larga`);
  /// 2) si `tipo` está vacío, lo infiere del nombre de la hoja ("Accesorios");
  /// 3) por defecto munición (planillas CCI vienen sin columna `tipo`).
  static ProductType resolveProductType({
    required String? tipoRaw,
    required String? sheetName,
  }) {
    final typeKey = (tipoRaw ?? '').trim().toLowerCase();
    if (typeKey.isNotEmpty) {
      return _productTypeFromKey(typeKey);
    }
    return _productTypeFromSheetName(sheetName) ?? ProductType.municion;
  }

  static ProductType _productTypeFromKey(String typeKey) {
    switch (typeKey) {
      case 'municion':
      case 'munición':
        return ProductType.municion;
      case 'arma_corta':
        return ProductType.armaCorta;
      case 'arma_larga':
        return ProductType.armaLarga;
      case 'accesorio':
      case 'accesorios':
        return ProductType.accesorios;
      default:
        throw FormatException('Tipo inválido: $typeKey');
    }
  }

  static ProductType? _productTypeFromSheetName(String? sheetName) {
    final normalized = (sheetName ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    if (normalized == 'accesorio' || normalized == 'accesorios') {
      return ProductType.accesorios;
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
    // Precio: flexible (planillas CCI, Stopping Power, export propio, armerías).
    if (h.startsWith('precio')) return 'precio_usd';
    if (h.contains('dolar')) return 'precio_usd'; // "Dolares u$s", "Dólares", etc.
    if (h == 'usd' ||
        h == 'u\$d' ||
        h == 'u\$s' ||
        h == '\$' ||
        h.startsWith('u\$d') ||
        h.startsWith('u\$s') ||
        h == 'importe' ||
        h == 'valor' ||
        h == 'pvp' ||
        h.startsWith('pvp ') ||
        h == 'monto' ||
        h == 'cotizacion' ||
        h.contains('p. unit') ||
        h.contains('p unit') ||
        h == 'punit' ||
        h == 'punitario') {
      return 'precio_usd';
    }

    switch (h) {
      case 'tipo':
      case 'type':
      case 'categoria':
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
      case 'model':
        return 'modelo';
      case 'codigo':
      case 'code':
      case 'cod':
      case 'sku':
      case 'cod.':
      case 'nro':
      case 'nro.':
      case 'numero':
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
      case 'caja por':
      case 'balas/caja':
      case 'x caja':
      case 'unidades por caja':
      case 'u/caja':
      case 'por': // Stopping Power: columna "por" = balas/caja
        return 'balas_por_caja';
      case 'stock':
      case 'cajas':
      case 'stock_cajas':
      case 'stock cajas':
      case 'stock (cajas)':
      case 'stock(cajas)':
      case 'total de cajas':
      case 'total cajas':
      case 'existencia':
      case 'existencias':
        return 'stock';
      case 'total':
      case 'total_balas':
      case 'total balas':
      case 'balas':
      case 'balas_total':
      case 'mayorista': // Stopping Power: total de balas
        return 'total_balas';
      case 'stock_inicial':
      case 'inicial':
        return 'stock_inicial';
      case 'vendido':
        return 'vendido';
      // Precios fijos (Urban Tactical): se cargan tal cual, sin recalcular.
      case 'efectivo_ars':
      case 'transferencia_ars':
        return 'efectivo_ars';
      case 'efectivo_usd':
        return 'efectivo_usd';
      case 'tarjeta_ars':
      case 'pvp_tarjeta_ars':
        return 'tarjeta_ars';
      case 'cuota3_ars':
        return 'cuota3_ars';
      case 'cuota6_ars':
        return 'cuota6_ars';
      case 'cuota12_ars':
        return 'cuota12_ars';
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
    final maxScan = rows.length < 40 ? rows.length : 40;
    _HeaderMatch? best;
    final sampleHeaders = <String>[];

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
          if (h < 8 && curText.trim().isNotEmpty && sampleHeaders.length < 12) {
            final t = curText.trim();
            if (!sampleHeaders.contains(t)) sampleHeaders.add(t);
          }
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
      final hint = sampleHeaders.isEmpty
          ? ''
          : ' Celdas vistas: ${sampleHeaders.take(8).join(', ')}.';
      throw Exception(
        'No encontré los encabezados en el Excel. Necesito al menos una columna '
        'de código/descripción/modelo y otra de precio (precio_usd, USD, PVP, '
        'importe). Tip: usá "EXPORTAR EXCEL" como plantilla, o si es .xls/CSV '
        'guardalo como .xlsx.$hint',
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

  /// Detecta marca de forma estructural (sin lista fija de marcas):
  /// 1) "Marca: X" / "MARCA X" en el preámbulo
  /// 2) Fila título con un solo valor (ej. celda fusionada "ORBEA")
  /// 3) Nombre de la hoja si parece una marca
  static String? _detectBrand(
    List<List<Data?>> rows,
    int upTo, {
    String? sheetName,
  }) {
    final withColon = RegExp(r'marca\s*:\s*(.+)', caseSensitive: false);
    final withoutColon = RegExp(r'^marca\s+(.+)$', caseSensitive: false);

    for (var r = 0; r < upTo && r < rows.length; r++) {
      for (final cell in rows[r]) {
        final text = _cellText(cell).replaceAll('\u00a0', ' ').trim();
        final match =
            withColon.firstMatch(text) ?? withoutColon.firstMatch(text);
        if (match != null) {
          final brand = normalizeBrandCandidate(match.group(1) ?? '');
          if (brand != null) return brand;
        }
      }
    }

    for (var r = 0; r < upTo && r < rows.length; r++) {
      final fromTitle = _brandFromTitleRow(rows[r]);
      if (fromTitle != null) return fromTitle;
    }

    return normalizeBrandCandidate(sheetName ?? '');
  }

  /// Fila de título típica de proveedor: una sola celda con texto (a veces
  /// fusionada). Ej: fila "ORBEA" arriba de Código / Descripción / …
  static String? _brandFromTitleRow(List<Data?> row) {
    final texts = <String>[];
    for (final cell in row) {
      final t = _cellText(cell).replaceAll('\u00a0', ' ').trim();
      if (t.isNotEmpty) texts.add(t);
    }
    if (texts.isEmpty) return null;
    // Misma marca repetida en celdas fusionadas, o un único valor.
    final unique = texts.toSet();
    if (unique.length != 1) return null;
    return normalizeBrandCandidate(unique.first);
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

  /// Lee **todas** las hojas del workbook. Marca por hoja (título / Marca: / nombre).
  List<Map<String, String>> parseRows(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('El Excel está vacío');
    }

    final rows = <Map<String, String>>[];
    final errors = <String>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) continue;

      try {
        rows.addAll(_parseSheet(sheet.rows, sheetName: sheetName));
      } catch (error) {
        errors.add('$sheetName: $error');
      }
    }

    if (rows.isEmpty) {
      final detail = errors.isEmpty
          ? 'No encontré filas de productos debajo de los encabezados.'
          : errors.join(' · ');
      throw Exception(detail);
    }

    return rows;
  }

  List<Map<String, String>> _parseSheet(
    List<List<Data?>> sheetRows, {
    required String sheetName,
  }) {
    // No exigimos "marca"/"calibre" (las planillas de proveedor no las traen).
    final header = _findHeader(sheetRows);
    final columnIndex = header.columns;
    final brand = _detectBrand(
      sheetRows,
      header.dataStart,
      sheetName: sheetName,
    );

    final rows = <Map<String, String>>[];

    for (var r = header.dataStart; r < sheetRows.length; r++) {
      final row = sheetRows[r];
      if (row.isEmpty || row.every((cell) => _cellText(cell).trim().isEmpty)) {
        continue;
      }

      final data = <String, String>{};
      for (final entry in columnIndex.entries) {
        final cell = entry.value < row.length ? row[entry.value] : null;
        data[entry.key] = _cellText(cell).replaceAll('\u00a0', ' ').trim();
      }

      final hasData = (data['codigo']?.isNotEmpty ?? false) ||
          (data['descripcion']?.isNotEmpty ?? false) ||
          (data['modelo']?.isNotEmpty ?? false);
      if (!hasData) continue;

      if (brand != null && (data['marca']?.isEmpty ?? true)) {
        data['marca'] = brand;
      }
      data['_sheet'] = sheetName;
      rows.add(data);
    }

    if (rows.isEmpty) {
      throw Exception('sin filas de producto');
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
    this.fixedPrices,
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

  /// Precios fijos del Excel (Urban): se muestran tal cual, sin recalcular.
  final FixedPrices? fixedPrices;

  bool get isMunicion => type == ProductType.municion;

  bool get isAccesorios => type == ProductType.accesorios;

  factory ExcelProductRow.fromMap(Map<String, String> data) {
    // tipo: columna explícita, si falta se infiere de la hoja, y por último
    // munición (planillas CCI son munición y no traen columna `tipo`).
    final type = ExcelCatalogService.resolveProductType(
      tipoRaw: data['tipo'],
      sheetName: data['_sheet'],
    );

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

    // Fail-closed: sin marca detectada no inventamos CCI.
    final marca = data['marca']?.trim() ?? '';

    // Munición estilo proveedor: datos empaquetados en la descripción.
    if (type == ProductType.municion && descripcion.isNotEmpty) {
      final parsed = ExcelCatalogService.parseMunicionDescription(descripcion);
      if (calibre.isEmpty) calibre = parsed.calibre;
      if (modelo.isEmpty) modelo = parsed.modelo;
    }

    final fixedPrices = FixedPrices.fromJson({
      'efectivo_ars': _parseFixed(data['efectivo_ars']),
      'efectivo_usd': _parseFixed(data['efectivo_usd']),
      'tarjeta_ars': _parseFixed(data['tarjeta_ars']),
      'cuota3_ars': _parseFixed(data['cuota3_ars']),
      'cuota6_ars': _parseFixed(data['cuota6_ars']),
      'cuota12_ars': _parseFixed(data['cuota12_ars']),
    });

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
      fixedPrices: fixedPrices,
    );
  }

  /// Monto de precio fijo: vacío/0 → null (no se computa nada, se muestra tal cual).
  static double? _parseFixed(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = _parsePrice(value);
    return parsed > 0 ? parsed : null;
  }

  static int? _parseInt(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    // Entero con separador de miles (1.000 / 1,000). Rechaza decimales tipo 12.5.
    if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(value)) {
      final normalized = value.replaceAll('.', '').replaceAll(',', '');
      return int.tryParse(normalized);
    }
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return int.tryParse(value);
    }
    // "12.5" / "10,5" no son enteros de stock.
    return null;
  }

  /// Precio USD: soporta "12.5", "12,50", "1.234,56", "U\$D 12", etc.
  /// Vacío → 0. Texto no numérico → FormatException (no 0 silencioso).
  static double _parsePrice(String? raw) {
    final original = (raw ?? '').replaceAll('\u00a0', ' ').trim();
    if (original.isEmpty) return 0;

    var value = original.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (value.isEmpty || value == '-' || value == '.' || value == ',') {
      throw FormatException('Precio inválido: $original');
    }

    final hasComma = value.contains(',');
    final hasDot = value.contains('.');
    if (hasComma && hasDot) {
      if (value.lastIndexOf(',') > value.lastIndexOf('.')) {
        value = value.replaceAll('.', '').replaceAll(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (hasComma) {
      value = value.replaceAll(',', '.');
    } else if (hasDot) {
      // Solo puntos: si hay grupos de miles (1.234 o 1.234.567) → miles AR.
      final parts = value.split('.');
      if (parts.length > 2 && parts.skip(1).every((p) => p.length == 3)) {
        value = parts.join();
      } else if (parts.length == 2 &&
          parts[0].isNotEmpty &&
          parts[1].length == 3 &&
          !parts[0].contains(RegExp(r'\D'))) {
        // Ambiguo "1.234": tratamos como miles (1234), típico en planillas AR.
        value = parts.join();
      }
    }

    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw FormatException('Precio inválido: $original');
    }
    return parsed;
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
      fixedPrices: fixedPrices,
    );
  }
}
