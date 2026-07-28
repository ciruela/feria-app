import 'package:app_feria/models/product.dart';
import 'package:app_feria/services/stock_cierre_service.dart';
import 'package:flutter_test/flutter_test.dart';

Product _municion(String id, {int? rpb, int? stock}) => Product(
      id: id,
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '22',
      codigo: id,
      precioUsd: 10,
      roundsPerBox: rpb,
      stock: stock,
    );

Product _arma(String id) => Product(
      id: id,
      type: ProductType.armaCorta,
      marca: 'Glock',
      calibre: '9',
      codigo: id,
      precioUsd: 500,
      stock: 1,
    );

CierreLine _line({
  required Product product,
  int apertura = 0,
  int vendido = 0,
  int carga = 0,
  int ajuste = 0,
  int cierre = 0,
}) =>
    CierreLine(
      product: product,
      aperturaCajas: apertura,
      vendidoCajas: vendido,
      cargaCajas: carga,
      ajusteCajas: ajuste,
      cierreCajas: cierre,
    );

void main() {
  group('CierreLine', () {
    test('balas derivadas para munición', () {
      final line = _line(
        product: _municion('m1', rpb: 50),
        apertura: 5,
        vendido: 2,
        cierre: 3,
      );
      expect(line.aperturaBalas, 250);
      expect(line.vendidoBalas, 100);
      expect(line.cierreBalas, 150);
      expect(line.tieneActividad, isTrue);
    });

    test('armas no tienen balas', () {
      final line = _line(product: _arma('a1'), vendido: 1, cierre: 0);
      expect(line.aperturaBalas, isNull);
      expect(line.vendidoBalas, isNull);
    });

    test('sin actividad', () {
      final line = _line(product: _municion('m2', rpb: 50), cierre: 5);
      expect(line.tieneActividad, isFalse);
    });
  });

  group('CierreResumen', () {
    final resumen = CierreResumen(
      day: DateTime(2026, 1, 1),
      lines: [
        _line(
            product: _municion('m1', rpb: 50),
            apertura: 5,
            vendido: 2,
            cierre: 3),
        _line(
            product: _municion('m2', rpb: 20),
            apertura: 10,
            vendido: 5,
            cierre: 5),
        _line(product: _arma('a1'), apertura: 2, vendido: 1, cierre: 1),
      ],
    );

    test('totales de munición y armas', () {
      expect(resumen.totalCajasVendidas, 7); // 2 + 5
      expect(resumen.totalBalasVendidas, 200); // 100 + 100
      expect(resumen.totalArmasVendidas, 1);
      expect(resumen.totalBalasCierre, 250); // 150 + 100
      expect(resumen.municion.length, 2);
      expect(resumen.armas.length, 1);
      expect(resumen.isEmpty, isFalse);
    });

    test('resumen vacío cuando no hay actividad', () {
      final vacio = CierreResumen(
        day: DateTime(2026, 1, 1),
        lines: [_line(product: _municion('m3', rpb: 50), cierre: 3)],
      );
      expect(vacio.isEmpty, isTrue);
    });
  });

  group('StockAlCierre', () {
    test('suma totales del catálogo', () {
      final products = [
        _municion('m1', rpb: 50, stock: 10),
        _municion('m2', rpb: 20, stock: 5),
        _arma('a1'),
        _municion('m3', rpb: 50, stock: 0),
        _municion('m4', rpb: 50),
      ];
      final totals = StockCierreService().stockAlCierre(products);
      expect(totals.productosConStock, 3);
      expect(totals.cajasMunicion, 15);
      expect(totals.balasMunicion, 600);
      expect(totals.unidadesArmas, 1);
    });
  });

  group('exportToExcel', () {
    test('genera bytes no vacíos', () {
      final resumen = CierreResumen(
        day: DateTime(2026, 1, 1),
        lines: [
          _line(
              product: _municion('m1', rpb: 50),
              apertura: 5,
              vendido: 2,
              cierre: 3),
        ],
      );
      final bytes = StockCierreService().exportToExcel(resumen);
      expect(bytes.length, greaterThan(0));
    });

    test('exportCierreCompleto genera bytes con ventas y stock', () {
      final resumen = CierreResumen(
        day: DateTime(2026, 1, 1),
        lines: [
          _line(
            product: _municion('m1', rpb: 50),
            apertura: 5,
            vendido: 2,
            cierre: 3,
          ),
        ],
      );
      final stock = const StockAlCierre(
        cajasMunicion: 100,
        balasMunicion: 5000,
        unidadesArmas: 12,
        productosConStock: 50,
      );
      final bytes = StockCierreService().exportCierreCompleto(
        resumen: resumen,
        ventas: const [],
        stockAlCierre: stock,
      );
      expect(bytes.length, greaterThan(0));
    });
  });
}
