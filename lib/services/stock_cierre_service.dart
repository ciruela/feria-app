import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/sale_record.dart';
import '../models/stock_movimiento.dart';
import 'supabase_stock_movimientos_repository.dart';

/// Reconciliación de stock de un día: apertura → movimientos → cierre.
class CierreLine {
  const CierreLine({
    required this.product,
    required this.aperturaCajas,
    required this.vendidoCajas,
    required this.cargaCajas,
    required this.ajusteCajas,
    required this.cierreCajas,
  });

  final Product product;

  /// Unidades vendibles (cajas para munición, unidades para armas).
  final int aperturaCajas;
  final int vendidoCajas;
  final int cargaCajas;
  final int ajusteCajas;
  final int cierreCajas;

  bool get isMunicion => product.isMunicion;
  int? get roundsPerBox => product.roundsPerBox;

  int? _balas(int cajas) =>
      isMunicion && roundsPerBox != null ? cajas * roundsPerBox! : null;

  int? get aperturaBalas => _balas(aperturaCajas);
  int? get vendidoBalas => _balas(vendidoCajas);
  int? get cierreBalas => _balas(cierreCajas);

  bool get tieneActividad =>
      vendidoCajas != 0 || cargaCajas != 0 || ajusteCajas != 0;
}

class CierreResumen {
  const CierreResumen({
    required this.startDate,
    required this.endDate,
    required this.lines,
  });

  final DateTime startDate;
  final DateTime endDate;
  final List<CierreLine> lines;

  bool get isSingleDay =>
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  Iterable<CierreLine> get municion => lines.where((l) => l.isMunicion);
  Iterable<CierreLine> get armas => lines.where((l) => !l.isMunicion);

  /// Solo productos con ventas, cargas o ajustes en el día.
  Iterable<CierreLine> get conActividad =>
      lines.where((l) => l.tieneActividad);

  int get totalCajasVendidas =>
      municion.fold(0, (sum, l) => sum + l.vendidoCajas);

  int get totalBalasVendidas =>
      municion.fold(0, (sum, l) => sum + (l.vendidoBalas ?? 0));

  int get totalArmasVendidas => armas.fold(0, (sum, l) => sum + l.vendidoCajas);

  int get totalBalasCierre =>
      municion.fold(0, (sum, l) => sum + (l.cierreBalas ?? 0));

  bool get isEmpty => !conActividad.any((l) => true);
}

/// Totales de stock actual de la armería (sin listar cada producto).
class StockAlCierre {
  const StockAlCierre({
    required this.cajasMunicion,
    required this.balasMunicion,
    required this.unidadesArmas,
    required this.productosConStock,
  });

  final int cajasMunicion;
  final int balasMunicion;
  final int unidadesArmas;
  final int productosConStock;
}

class StockCierreService {
  final SupabaseStockMovimientosRepository _movimientos =
      SupabaseStockMovimientosRepository();

  Future<CierreResumen> cierreForDay(
    DateTime day,
    List<Product> products,
  ) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return cierreForRange(start, end, products, endDateInclusive: day);
  }

  Future<CierreResumen> cierreForRange(
    DateTime start,
    DateTime end,
    List<Product> products, {
    DateTime? endDateInclusive,
  }) async {
    final movimientos = await _movimientos.fetchForRange(start, end);
    final inclusiveEnd = endDateInclusive ??
        end.subtract(const Duration(days: 1));

    final byProduct = <String, List<StockMovimiento>>{};
    for (final mov in movimientos) {
      byProduct.putIfAbsent(mov.productoId, () => []).add(mov);
    }

    final lines = <CierreLine>[];

    for (final product in products) {
      final movs = byProduct[product.id] ?? const <StockMovimiento>[];
      if (movs.isEmpty) continue;

      final line = _lineFromMovimientos(product: product, movs: movs);
      if (line != null) lines.add(line);
    }

    // Movimientos de productos ya eliminados del catálogo (huérfanos).
    final knownIds = products.map((p) => p.id).toSet();
    for (final entry in byProduct.entries) {
      if (knownIds.contains(entry.key)) continue;
      final line = _lineFromMovimientos(
        product: _orphanProduct(entry.key),
        movs: entry.value,
      );
      if (line != null) lines.add(line);
    }

    lines.sort((a, b) {
      // Con actividad primero, luego por marca.
      if (a.tieneActividad != b.tieneActividad) {
        return a.tieneActividad ? -1 : 1;
      }
      final marca = a.product.marca.toLowerCase().compareTo(
            b.product.marca.toLowerCase(),
          );
      if (marca != 0) return marca;
      return a.product.codigo.compareTo(b.product.codigo);
    });

    return CierreResumen(
      startDate: start,
      endDate: inclusiveEnd,
      lines: lines,
    );
  }

  /// Expuesto para tests unitarios de reconciliación.
  @visibleForTesting
  CierreLine? reconcileLine({
    required Product product,
    required List<StockMovimiento> movs,
  }) =>
      _lineFromMovimientos(product: product, movs: movs);

  /// Reconcilia apertura/cierre desde movimientos auditados (`stock_antes` /
  /// `stock_despues`), no desde el stock actual del catálogo en caché.
  CierreLine? _lineFromMovimientos({
    required Product product,
    required List<StockMovimiento> movs,
  }) {
    if (movs.isEmpty) return null;

    var ventaDelta = 0;
    var cargaDelta = 0;
    var ajusteDelta = 0;
    for (final mov in movs) {
      switch (mov.motivo) {
        case StockMotivo.venta:
        case StockMotivo.anulacion:
          ventaDelta += mov.delta;
        case StockMotivo.carga:
          cargaDelta += mov.delta;
        case StockMotivo.ajuste:
          ajusteDelta += mov.delta;
      }
    }

    final sorted = [...movs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final netDelta = ventaDelta + cargaDelta + ajusteDelta;

    final cierre = sorted.last.stockDespues ?? product.stock ?? 0;
    final apertura = sorted.first.stockAntes ?? (cierre - netDelta);

    return CierreLine(
      product: product,
      aperturaCajas: apertura,
      vendidoCajas: -ventaDelta,
      cargaCajas: cargaDelta,
      ajusteCajas: ajusteDelta,
      cierreCajas: cierre,
    );
  }

  Product _orphanProduct(String id) => Product(
        id: id,
        type: ProductType.municion,
        marca: '(eliminado)',
        calibre: '',
        codigo: id,
        precioUsd: 0,
      );

  StockAlCierre stockAlCierre(List<Product> products) {
    var cajasMunicion = 0;
    var balasMunicion = 0;
    var unidadesArmas = 0;
    var productosConStock = 0;

    for (final product in products) {
      final stock = product.stock;
      if (stock == null || stock <= 0) continue;
      productosConStock++;
      if (product.isMunicion) {
        cajasMunicion += stock;
        final rpb = product.roundsPerBox;
        if (rpb != null && rpb > 0) balasMunicion += stock * rpb;
      } else if (product.isArma) {
        unidadesArmas += stock;
      }
    }

    return StockAlCierre(
      cajasMunicion: cajasMunicion,
      balasMunicion: balasMunicion,
      unidadesArmas: unidadesArmas,
      productosConStock: productosConStock,
    );
  }

  Uint8List exportToExcel(CierreResumen resumen) {
    return exportCierreCompleto(
      resumen: resumen,
      ventas: const [],
      stockAlCierre: const StockAlCierre(
        cajasMunicion: 0,
        balasMunicion: 0,
        unidadesArmas: 0,
        productosConStock: 0,
      ),
    );
  }

  Uint8List exportCierreCompleto({
    required CierreResumen resumen,
    required List<SaleRecord> ventas,
    required StockAlCierre stockAlCierre,
  }) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;

    _writeResumenSheet(
      excel,
      defaultName,
      resumen: resumen,
      ventas: ventas,
      stockAlCierre: stockAlCierre,
    );

    final ventasSheet = excel['Ventas'];
    _writeVentasSheet(ventasSheet, ventas);

    final detalleSheet = excel['Detalle ventas'];
    _writeDetalleVentasSheet(detalleSheet, ventas);

    final movSheet = excel['Movimientos'];
    _writeMovimientosSheet(movSheet, resumen.conActividad.toList());

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el Excel del cierre');
    }
    return Uint8List.fromList(bytes);
  }

  void _writeResumenSheet(
    Excel excel,
    String sheetName, {
    required CierreResumen resumen,
    required List<SaleRecord> ventas,
    required StockAlCierre stockAlCierre,
  }) {
    excel.rename(sheetName, 'Resumen');
    final sheet = excel['Resumen'];

    var ventasArs = 0.0;
    var ventasUsd = 0.0;
    var comprobantes = 0;
    var facturadas = 0;
    var pendientes = 0;
    for (final sale in ventas) {
      if (sale.anulada) continue;
      comprobantes++;
      ventasArs += sale.collectedArs;
      ventasUsd += sale.collectedUsd;
      if (sale.facturada) {
        facturadas++;
      } else {
        pendientes++;
      }
    }

    final periodLabel = resumen.isSingleDay
        ? _formatDay(resumen.startDate)
        : '${_formatDay(resumen.startDate)} — ${_formatDay(resumen.endDate)}';

    final rows = <List<String>>[
      ['Período', periodLabel],
      ['Comprobantes', '$comprobantes'],
      ['Facturadas', '$facturadas'],
      ['Pendientes facturar', '$pendientes'],
      ['Cobrado ARS', ventasArs.toStringAsFixed(0)],
      ['Cobrado USD', ventasUsd.toStringAsFixed(2)],
      ['', ''],
      ['VENDIDO (stock)', ''],
      ['Cajas munición', '${resumen.totalCajasVendidas}'],
      ['Balas munición', '${resumen.totalBalasVendidas}'],
      ['Armas', '${resumen.totalArmasVendidas}'],
      ['', ''],
      ['STOCK AL CIERRE (actual)', ''],
      ['Productos con stock', '${stockAlCierre.productosConStock}'],
      ['Cajas munición', '${stockAlCierre.cajasMunicion}'],
      ['Balas munición', '${stockAlCierre.balasMunicion}'],
      ['Unidades armas', '${stockAlCierre.unidadesArmas}'],
    ];

    for (var r = 0; r < rows.length; r++) {
      _write(sheet, 0, r, rows[r][0]);
      _write(sheet, 1, r, rows[r][1]);
    }
  }

  void _writeVentasSheet(Sheet sheet, List<SaleRecord> ventas) {
    const headers = [
      'hora',
      'cliente',
      'dni',
      'vendedor',
      'total_ars',
      'total_usd',
      'anulada',
      'facturada',
      'factura_numero',
      'facturada_por',
      'facturada_at',
    ];
    for (var col = 0; col < headers.length; col++) {
      _write(sheet, col, 0, headers[col]);
    }

    final sorted = [...ventas]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (var i = 0; i < sorted.length; i++) {
      final sale = sorted[i];
      final t = sale.createdAt;
      final hora =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      final r = i + 1;
      _write(sheet, 0, r, hora);
      _write(sheet, 1, r, sale.clienteNombre);
      _write(sheet, 2, r, sale.clienteDni);
      _write(sheet, 3, r, sale.sellerName ?? '');
      _write(sheet, 4, r, sale.collectedArs.toStringAsFixed(0));
      _write(sheet, 5, r, sale.collectedUsd.toStringAsFixed(2));
      _write(sheet, 6, r, sale.anulada ? 'SI' : 'NO');
      _write(sheet, 7, r, sale.facturada ? 'SI' : 'NO');
      _write(sheet, 8, r, sale.facturaNumero);
      _write(sheet, 9, r, sale.facturadaPor);
      _write(
        sheet,
        10,
        r,
        sale.facturadaAt == null ? '' : sale.facturadaAt!.toIso8601String(),
      );
    }
  }

  Uint8List exportVentasList(List<SaleRecord> ventas) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Comprobantes');
    _writeVentasSheet(excel['Comprobantes'], ventas);

    final detalleSheet = excel['Detalle ventas'];
    _writeDetalleVentasSheet(detalleSheet, ventas);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el Excel de comprobantes');
    }
    return Uint8List.fromList(bytes);
  }

  void _writeDetalleVentasSheet(Sheet sheet, List<SaleRecord> ventas) {
    const headers = [
      'hora',
      'cliente',
      'detalle',
      'cantidad',
      'importe_ars',
      'importe_usd',
      'anulada',
    ];
    for (var col = 0; col < headers.length; col++) {
      _write(sheet, col, 0, headers[col]);
    }

    var row = 1;
    final sorted = [...ventas]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final sale in sorted) {
      final t = sale.createdAt;
      final hora =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      for (final line in sale.lines) {
        _write(sheet, 0, row, hora);
        _write(sheet, 1, row, sale.clienteNombre);
        _write(
          sheet,
          2,
          row,
          line.detail.isNotEmpty
              ? line.detail
              : (line.code.isNotEmpty ? line.code : line.productId),
        );
        _write(sheet, 3, row, '${line.quantity}');
        _write(
          sheet,
          4,
          row,
          line.paysInUsd ? '' : line.lineArs.toStringAsFixed(0),
        );
        _write(
          sheet,
          5,
          row,
          line.paysInUsd ? line.lineUsd.toStringAsFixed(2) : '',
        );
        _write(sheet, 6, row, sale.anulada ? 'SI' : 'NO');
        row++;
      }
    }
  }

  void _writeMovimientosSheet(Sheet sheet, List<CierreLine> lines) {
    const headers = [
      'tipo',
      'marca',
      'calibre',
      'codigo',
      'descripcion',
      'balas_por_caja',
      'apertura_cajas',
      'vendido_cajas',
      'carga_cajas',
      'ajuste_cajas',
      'cierre_cajas',
      'apertura_balas',
      'vendido_balas',
      'cierre_balas',
    ];

    for (var col = 0; col < headers.length; col++) {
      _write(sheet, col, 0, headers[col]);
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final p = line.product;
      final r = i + 1;
      _write(sheet, 0, r, p.type.key);
      _write(sheet, 1, r, p.marca);
      _write(sheet, 2, r, p.calibre);
      _write(sheet, 3, r, p.codigo);
      _write(sheet, 4, r, p.descripcion);
      _write(sheet, 5, r, p.roundsPerBox?.toString() ?? '');
      _write(sheet, 6, r, '${line.aperturaCajas}');
      _write(sheet, 7, r, '${line.vendidoCajas}');
      _write(sheet, 8, r, '${line.cargaCajas}');
      _write(sheet, 9, r, '${line.ajusteCajas}');
      _write(sheet, 10, r, '${line.cierreCajas}');
      _write(sheet, 11, r, line.aperturaBalas?.toString() ?? '');
      _write(sheet, 12, r, line.vendidoBalas?.toString() ?? '');
      _write(sheet, 13, r, line.cierreBalas?.toString() ?? '');
    }
  }

  static String _formatDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Legacy single-sheet export kept for tests — writes movimientos only.
  Uint8List _exportMovimientosOnly(CierreResumen resumen) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Cierre');
    _writeMovimientosSheet(excel['Cierre'], resumen.lines);
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el Excel del cierre');
    }
    return Uint8List.fromList(bytes);
  }

  Uint8List exportMovimientosExcel(CierreResumen resumen) =>
      _exportMovimientosOnly(resumen);

  static void _write(Sheet sheet, int col, int row, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(value);
  }
}
