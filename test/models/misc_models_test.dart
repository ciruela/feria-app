import 'package:app_feria/models/admin_user.dart';
import 'package:app_feria/models/audit_entry.dart';
import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/models/seller.dart';
import 'package:app_feria/models/stock_movimiento.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Seller', () {
    test('roundtrip json y copyWith', () {
      const s = Seller(id: 'v1', nombre: 'Ana');
      final back = Seller.fromJson(s.toJson());
      expect(back.nombre, 'Ana');
      expect(back.activo, isTrue);
      expect(s.copyWith(activo: false).activo, isFalse);
    });
  });

  group('AdminUser', () {
    test('roundtrip json con default activo', () {
      final a = AdminUser.fromJson(const {'id': 'a', 'nombre': 'Jefe'});
      expect(a.pin, '');
      expect(a.activo, isTrue);
      expect(a.toJson()['nombre'], 'Jefe');
      expect(a.copyWith(pin: '1234').pin, '1234');
    });
  });

  group('StockMotivo', () {
    test('fromKey y fallback a ajuste', () {
      expect(StockMotivo.fromKey('venta'), StockMotivo.venta);
      expect(StockMotivo.fromKey('anulacion'), StockMotivo.anulacion);
      expect(StockMotivo.fromKey('desconocido'), StockMotivo.ajuste);
      expect(StockMotivo.fromKey(null), StockMotivo.ajuste);
    });
  });

  group('StockMovimiento', () {
    test('fromRow y entrada/salida', () {
      final entrada = StockMovimiento.fromRow(const {
        'id': 'm1',
        'producto_id': 'p1',
        'delta': 5,
        'motivo': 'carga',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(entrada.isEntrada, isTrue);
      expect(entrada.isSalida, isFalse);

      final salida = StockMovimiento.fromRow(const {
        'id': 'm2',
        'producto_id': 'p1',
        'delta': -2,
        'motivo': 'venta',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(salida.isSalida, isTrue);
      expect(salida.motivo, StockMotivo.venta);
    });
  });

  group('AuditEntidad', () {
    test('label conocido y fallback', () {
      expect(AuditEntidad.label(AuditEntidad.producto), 'Productos');
      expect(AuditEntidad.label('otro'), 'otro');
      expect(AuditEntidad.all, contains(AuditEntidad.venta));
    });
  });

  group('AuditEntry', () {
    test('fromRow con defaults', () {
      final e = AuditEntry.fromRow(const {
        'id': 'e1',
        'accion': 'Creó producto',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(e.accion, 'Creó producto');
      expect(e.actorNombre, '');
      expect(e.entidad, '');
    });
  });

  group('CartCheckoutPayment', () {
    test('single no es dual', () {
      const p = CartCheckoutPayment.single(PaymentMethod.efectivo);
      expect(p.isDual, isFalse);
      expect(p.primaryShare, 1.0);
      expect(p.secondaryShare, 0.0);
    });

    test('dual reparte shares', () {
      const p = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.lista,
        secondMethod: PaymentMethod.dolarBillete,
        primaryShare: 0.6,
      );
      expect(p.isDual, isTrue);
      expect(p.secondaryMethod, PaymentMethod.dolarBillete);
      expect(p.secondaryShare, closeTo(0.4, 1e-9));
    });

    test('PaymentAllocation.paysInUsd', () {
      const a = PaymentAllocation(
          method: PaymentMethod.dolarBillete, amountUsd: 10, amountArs: 0);
      expect(a.paysInUsd, isTrue);
    });
  });
}
