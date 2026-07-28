import 'package:app_feria/models/sale_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleLineRecord', () {
    test('fromJson con defaults', () {
      final l = SaleLineRecord.fromJson(const {});
      expect(l.quantity, 1);
      expect(l.paymentMethod, 'lista');
      expect(l.isArma, isFalse);
      expect(l.paysInUsd, isFalse);
    });

    test('paysInUsd para dólar billete', () {
      final l = SaleLineRecord.fromJson(const {
        'productId': 'p',
        'paymentMethod': 'dolar_billete',
        'lineUsd': 100,
      });
      expect(l.paysInUsd, isTrue);
    });

    test('resolvedProductType desde campo explícito', () {
      final l = SaleLineRecord.fromJson(const {
        'productId': 'x',
        'productType': 'arma_larga',
      });
      expect(l.resolvedProductType, 'arma_larga');
    });

    test('resolvedProductType infiere desde el id', () {
      expect(
        SaleLineRecord.fromJson(const {'productId': 'municion_9'})
            .resolvedProductType,
        'municion',
      );
      expect(
        SaleLineRecord.fromJson(const {'productId': 'arma_corta_2'})
            .resolvedProductType,
        'arma_corta',
      );
    });

    test('resolvedProductType cae a isArma', () {
      final l = SaleLineRecord.fromJson(const {'productId': 'zzz', 'isArma': true});
      expect(l.resolvedProductType, 'arma_corta');
    });

    test('isSplitSecondPart', () {
      final l = SaleLineRecord.fromJson(const {'productId': 'p', 'splitPart': 2});
      expect(l.isSplitSecondPart, isTrue);
    });
  });

  group('SaleRecord.fromRow', () {
    Map<String, dynamic> baseRow() => {
          'id': 's1',
          'created_at': '2026-01-15T12:00:00Z',
          'total_ars': 1000,
          'total_usd': 5,
          'vendedor_id': 'v1',
          'items': {
            'sellerName': 'Ana',
            'lines': [
              {'productId': 'p1', 'lineArs': 600, 'paymentMethod': 'lista'},
              {'productId': 'p2', 'lineUsd': 5, 'paymentMethod': 'dolar_billete'},
              {'productId': 'p3', 'lineArs': 400, 'paymentMethod': 'efectivo'},
            ],
          },
        };

    test('parsea campos y líneas', () {
      final s = SaleRecord.fromRow(baseRow());
      expect(s.id, 's1');
      expect(s.sellerName, 'Ana');
      expect(s.lines.length, 3);
      expect(s.anulada, isFalse);
      expect(s.hasPdf, isFalse);
    });

    test('collectedArs suma solo líneas en pesos', () {
      final s = SaleRecord.fromRow(baseRow());
      expect(s.collectedArs, 1000);
      expect(s.collectedUsd, 5);
    });

    test('lee campos de anulación', () {
      final row = baseRow()
        ..addAll({
          'anulada': true,
          'anulada_motivo': 'error',
          'anulada_por': 'Ana',
          'anulada_at': '2026-01-16T10:00:00Z',
          'pdf_path': 'ventas/s1.pdf',
        });
      final s = SaleRecord.fromRow(row);
      expect(s.anulada, isTrue);
      expect(s.anuladaMotivo, 'error');
      expect(s.hasPdf, isTrue);
      expect(s.anuladaAt, isNotNull);
    });
    test('toBudget reconstruye presupuesto desde items', () {
      final s = SaleRecord.fromRow({
        ...baseRow(),
        'cliente_nombre': 'Juan',
        'cliente_dni': '123',
        'items': {
          'sellerName': 'Ana',
          'date': '2026-01-15T15:30:00Z',
          'customer': {
            'fullName': 'Juan Pérez',
            'dni': '12345678',
          },
          'lines': [
            {
              'productId': 'p1',
              'detail': 'CCI 22',
              'quantity': 2,
              'lineArs': 600,
              'unitArs': 300,
              'paymentMethod': 'lista',
            },
          ],
        },
      });
      final budget = s.toBudget();
      expect(budget.customer.fullName, 'Juan Pérez');
      expect(budget.lines.length, 1);
      expect(budget.lines.first.lineArs, 600);
      expect(budget.sellerName, 'Ana');
    });
  });
}
