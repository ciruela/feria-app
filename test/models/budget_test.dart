import 'package:app_feria/models/budget.dart';
import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetLine _line({
  required PaymentMethod method,
  double ars = 0,
  double usd = 0,
  int? split,
}) =>
    BudgetLine(
      lineKey: 'k${method.key}$split',
      productId: 'p',
      code: 'C',
      quantity: 1,
      detail: 'd',
      unitArs: ars,
      lineArs: ars,
      unitUsd: usd,
      lineUsd: usd,
      paymentMethod: method,
      isArma: false,
      splitPart: split,
    );

void main() {
  group('BudgetLine', () {
    test('paysInUsd y labels', () {
      final usd = _line(method: PaymentMethod.dolarBillete, usd: 100);
      expect(usd.paysInUsd, isTrue);
      expect(usd.paymentLabel, PaymentMethod.dolarBillete.label);
      expect(usd.isSplitPart, isFalse);
    });

    test('isSplitPart cuando hay splitPart', () {
      expect(_line(method: PaymentMethod.lista, split: 1).isSplitPart, isTrue);
    });

    test('formateo plano sin símbolo', () {
      final ars = _line(method: PaymentMethod.lista, ars: 1000);
      expect(ars.formattedLinePlain.contains(r'$'), isFalse);
      final usd = _line(method: PaymentMethod.dolarBillete, usd: 50);
      expect(usd.formattedUnitPlain.contains('USD'), isFalse);
    });
  });

  group('Budget totales', () {
    test('desde líneas cuando no hay allocations', () {
      final budget = Budget(
        date: DateTime(2026, 1, 1),
        customer: const BudgetCustomer(),
        lines: [
          _line(method: PaymentMethod.lista, ars: 1000),
          _line(method: PaymentMethod.efectivo, ars: 500),
          _line(method: PaymentMethod.dolarBillete, usd: 20),
        ],
        totalUsd: 20,
        totalArs: 1500,
      );
      expect(budget.totalArsLines, 1500);
      expect(budget.totalUsdLines, 20);
      expect(budget.hasArsPayments, isTrue);
      expect(budget.hasUsdPayments, isTrue);
      expect(budget.paymentMethods.length, 3);
    });

    test('prioriza allocations cuando existen', () {
      final budget = Budget(
        date: DateTime(2026, 1, 1),
        customer: const BudgetCustomer(),
        lines: [_line(method: PaymentMethod.lista, ars: 999)],
        totalUsd: 0,
        totalArs: 0,
        paymentAllocations: const [
          PaymentAllocation(
            method: PaymentMethod.efectivo,
            amountUsd: 0,
            amountArs: 700,
          ),
          PaymentAllocation(
            method: PaymentMethod.dolarBillete,
            amountUsd: 10,
            amountArs: 0,
          ),
        ],
      );
      expect(budget.totalArsLines, 700);
      expect(budget.totalUsdLines, 10);
      expect(budget.paymentMethods,
          {PaymentMethod.efectivo, PaymentMethod.dolarBillete});
    });

    test('copyWithCustomer preserva líneas y totales', () {
      final budget = Budget(
        date: DateTime(2026, 1, 1),
        customer: const BudgetCustomer(fullName: 'A'),
        lines: [_line(method: PaymentMethod.lista, ars: 1)],
        totalUsd: 0,
        totalArs: 1,
      );
      final updated =
          budget.copyWithCustomer(const BudgetCustomer(fullName: 'B'));
      expect(updated.customer.fullName, 'B');
      expect(updated.lines, budget.lines);
    });
  });

  group('BudgetCustomer.copyWith', () {
    test('actualiza solo lo indicado', () {
      const c = BudgetCustomer(fullName: 'A', dni: '1');
      final u = c.copyWith(dni: '2');
      expect(u.fullName, 'A');
      expect(u.dni, '2');
    });
  });

  group('ProductBudgetX', () {
    test('detalle de arma incluye marca modelo calibre', () {
      const arma = Product(
        id: 'a',
        type: ProductType.armaCorta,
        marca: 'glock',
        calibre: '9',
        codigo: 'G17',
        modelo: 'G17',
        precioUsd: 500,
      );
      expect(arma.budgetDetail(), contains('GLOCK'));
      expect(arma.budgetDetail(), contains('Cal. 9'));
      expect(arma.budgetCode, 'G17');
    });

    test('detalle de munición usa código', () {
      const m = Product(
        id: 'm',
        type: ProductType.municion,
        marca: 'cci',
        calibre: '22',
        codigo: 'C-1',
        precioUsd: 10,
      );
      expect(m.budgetDetail(), contains('C-1'));
      expect(m.budgetCode, 'C-1');
    });
  });
}
