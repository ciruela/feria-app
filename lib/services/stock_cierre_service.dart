import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/product.dart';
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
    required this.day,
    required this.lines,
  });

  final DateTime day;
  final List<CierreLine> lines;

  Iterable<CierreLine> get municion => lines.where((l) => l.isMunicion);
  Iterable<CierreLine> get armas => lines.where((l) => !l.isMunicion);

  int get totalCajasVendidas =>
      municion.fold(0, (sum, l) => sum + l.vendidoCajas);

  int get totalBalasVendidas =>
      municion.fold(0, (sum, l) => sum + (l.vendidoBalas ?? 0));

  int get totalArmasVendidas => armas.fold(0, (sum, l) => sum + l.vendidoCajas);

  int get totalBalasCierre =>
      municion.fold(0, (sum, l) => sum + (l.cierreBalas ?? 0));

  bool get isEmpty => lines.every((l) => !l.tieneActividad);
}

class StockCierreService {
  final SupabaseStockMovimientosRepository _movimientos =
      SupabaseStockMovimientosRepository();

  Future<CierreResumen> cierreForDay(
    DateTime day,
    List<Product> products,
  ) async {
    final movimientos = await _movimientos.fetchForDay(day);

    final byProduct = <String, List<StockMovimiento>>{};
    for (final mov in movimientos) {
      byProduct.putIfAbsent(mov.productoId, () => []).add(mov);
    }

    final lines = <CierreLine>[];

    for (final product in products) {
      final movs = byProduct[product.id] ?? const <StockMovimiento>[];

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

      final netDelta = ventaDelta + cargaDelta + ajusteDelta;
      final cierre = product.stock ?? 0;
      final apertura = cierre - netDelta;

      // Sólo incluir productos con actividad o con stock definido.
      if (movs.isEmpty && product.stock == null) continue;

      lines.add(
        CierreLine(
          product: product,
          aperturaCajas: apertura,
          vendidoCajas: -ventaDelta,
          cargaCajas: cargaDelta,
          ajusteCajas: ajusteDelta,
          cierreCajas: cierre,
        ),
      );
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

    return CierreResumen(day: day, lines: lines);
  }

  Uint8List exportToExcel(CierreResumen resumen) {
    final excel = Excel.createExcel();
    final defaultName = excel.sheets.keys.first;
    excel.rename(defaultName, 'Cierre');
    final sheet = excel['Cierre'];

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
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = TextCellValue(headers[col]);
    }

    for (var i = 0; i < resumen.lines.length; i++) {
      final line = resumen.lines[i];
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

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('No se pudo generar el Excel del cierre');
    }
    return Uint8List.fromList(bytes);
  }

  static void _write(Sheet sheet, int col, int row, String value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(value);
  }
}
