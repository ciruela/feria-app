import 'package:app_feria/models/product_prices.dart';
import 'package:flutter_test/flutter_test.dart';

ProductPrices _prices() => const ProductPrices(
      usd: 100,
      lista: 150000,
      efectivo: 142500,
      debito: 157500,
      tarjeta1: 165000,
      tarjeta3: 172500,
      tarjeta6: 180000,
      tarjeta9: 195000,
      tarjeta12: 202500,
      tarjeta18: 217500,
    );

void main() {
  group('ProductPrices cuotas', () {
    test('divide el total por la cantidad de cuotas', () {
      final p = _prices();
      expect(p.cuota1, 165000);
      expect(p.cuota3, closeTo(57500, 0.01));
      expect(p.cuota6, closeTo(30000, 0.01));
      expect(p.cuota12, closeTo(16875, 0.01));
      expect(p.cuota18, closeTo(12083.33, 0.01));
    });
  });

  group('PaymentMethod', () {
    test('isUsdPayment para USD billete y USD transferencia', () {
      expect(PaymentMethod.dolarBillete.isUsdPayment, isTrue);
      expect(PaymentMethod.dolarTransferencia.isUsdPayment, isTrue);
      expect(PaymentMethod.efectivo.isUsdPayment, isFalse);
      expect(PaymentMethod.transferencia.isUsdPayment, isFalse);
    });

    test('USD transferencia cotiza igual que USD billete', () {
      final p = _prices();
      // Mismo monto que el billete: efectivo en ARS y % efectivo en USD.
      expect(PaymentMethod.dolarTransferencia.totalArsFor(p), 142500);
      expect(
        PaymentMethod.dolarTransferencia.totalArsFor(p),
        PaymentMethod.dolarBillete.totalArsFor(p),
      );
      expect(PaymentMethod.dolarTransferencia.totalUsdFor(p), closeTo(95, 0.01));
    });

    test('totalArsFor mapea cada método a su precio', () {
      final p = _prices();
      expect(PaymentMethod.lista.totalArsFor(p), 150000);
      expect(PaymentMethod.transferencia.totalArsFor(p), 150000);
      expect(PaymentMethod.dolarBillete.totalArsFor(p), 142500);
      expect(PaymentMethod.efectivo.totalArsFor(p), 142500);
      expect(PaymentMethod.debito.totalArsFor(p), 157500);
      expect(PaymentMethod.tarjeta6.totalArsFor(p), 180000);
      expect(PaymentMethod.tarjeta18.totalArsFor(p), 217500);
    });

    test('totalUsdFor en USD aplica descuento efectivo', () {
      final p = _prices();
      expect(PaymentMethod.tarjeta12.totalUsdFor(p), 100);
      expect(PaymentMethod.dolarBillete.totalUsdFor(p), closeTo(95, 0.01));
    });

    test('checkoutPaymentMethods incluye USD solo con includeUsd', () {
      expect(
        checkoutPaymentMethods(includeUsd: false),
        isNot(contains(PaymentMethod.dolarBillete)),
      );
      expect(
        checkoutPaymentMethods(includeUsd: true).first,
        PaymentMethod.dolarBillete,
      );
    });

    test('USD transferencia solo con includeUsdTransfer (WG)', () {
      // Sin la bandera (Urban / otros): no aparece.
      expect(
        checkoutPaymentMethods(includeUsd: true),
        isNot(contains(PaymentMethod.dolarTransferencia)),
      );
      // Con la bandera (World Guns): aparece junto al billete.
      final wg = checkoutPaymentMethods(
        includeUsd: true,
        includeUsdTransfer: true,
      );
      expect(wg, contains(PaymentMethod.dolarBillete));
      expect(wg, contains(PaymentMethod.dolarTransferencia));
      // Sin USD habilitado, la bandera no fuerza nada.
      expect(
        checkoutPaymentMethods(includeUsd: false, includeUsdTransfer: true),
        isNot(contains(PaymentMethod.dolarTransferencia)),
      );
    });

    test('shortLabel definido para todos los métodos', () {
      for (final m in PaymentMethod.values) {
        expect(m.shortLabel, isNotEmpty);
      }
    });

    test('key único por método', () {
      final keys = PaymentMethod.values.map((m) => m.key).toSet();
      expect(keys.length, PaymentMethod.values.length);
    });
  });
}
