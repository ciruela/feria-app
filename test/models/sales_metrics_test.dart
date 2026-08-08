import 'package:app_feria/models/sale_record.dart';
import 'package:app_feria/models/sales_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

SaleRecord _sale({
  required String id,
  required double ars,
  bool anulada = false,
  bool facturada = false,
}) {
  return SaleRecord(
    id: id,
    createdAt: DateTime(2026, 7, 25, 12, 0),
    sellerName: 'Vendedor',
    totalArs: ars,
    clienteNombre: 'Cliente $id',
    anulada: anulada,
    facturada: facturada,
    lines: [
      SaleLineRecord(
        productId: 'municion_$id',
        quantity: 2,
        lineArs: ars,
        lineUsd: 0,
        paymentMethod: 'efectivo',
        isArma: false,
        productType: 'municion',
      ),
    ],
  );
}

void main() {
  final day = DateTime(2026, 7, 25);

  test('ventas anuladas se excluyen de los totales', () {
    final metrics = DaySalesMetrics.fromSales(day, [
      _sale(id: 'a', ars: 1000),
      _sale(id: 'b', ars: 500, anulada: true),
    ]);

    expect(metrics.saleCount, 1);
    expect(metrics.totalArs, 1000);
    expect(metrics.municion.units, 2);
  });

  test('ventas anuladas siguen visibles en la lista de comprobantes', () {
    final metrics = DaySalesMetrics.fromSales(day, [
      _sale(id: 'a', ars: 1000),
      _sale(id: 'b', ars: 500, anulada: true),
    ]);

    expect(metrics.sales.length, 2);
    expect(metrics.sales.any((s) => s.anulada), isTrue);
  });

  test('pendienteFacturacion distingue facturadas', () {
    final metrics = DaySalesMetrics.fromSales(day, [
      _sale(id: 'a', ars: 1000),
      _sale(id: 'b', ars: 500, facturada: true),
    ]);

    expect(metrics.sales.where((s) => s.pendienteFacturacion).length, 1);
  });

  test('municionBalas deriva cajas × balas por caja del catálogo', () {
    // Dos ventas de munición: 2 cajas c/u = 4 cajas; con 50 balas/caja = 200.
    final metrics = DaySalesMetrics.fromSales(
      day,
      [
        _sale(id: 'a', ars: 1000),
        _sale(id: 'b', ars: 1000),
      ],
      roundsPerBoxOf: (_) => 50,
    );

    expect(metrics.municion.units, 4);
    expect(metrics.municionBalas, 200);
  });

  test('municionBalas es 0 sin resolver de balas por caja', () {
    final metrics = DaySalesMetrics.fromSales(day, [
      _sale(id: 'a', ars: 1000),
    ]);

    expect(metrics.municion.units, 2);
    expect(metrics.municionBalas, 0);
  });
}
