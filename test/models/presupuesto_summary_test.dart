import 'package:app_feria/models/budget.dart';
import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/presupuesto_summary.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:flutter_test/flutter_test.dart';

Budget _budget(List<PaymentAllocation> allocations) => Budget(
      date: DateTime(2026, 1, 1),
      customer: const BudgetCustomer(),
      lines: const [],
      totalUsd: 0,
      totalArs: 0,
      paymentAllocations: allocations,
    );

void main() {
  test('checks primarios reflejan métodos usados', () {
    final s = PresupuestoSummary(_budget(const [
      PaymentAllocation(
          method: PaymentMethod.efectivo, amountUsd: 0, amountArs: 100),
      PaymentAllocation(
          method: PaymentMethod.dolarBillete, amountUsd: 5, amountArs: 0),
    ]));

    final labels = {
      for (final c in s.primaryPaymentChecks) c.label: c.checked,
    };
    expect(labels['EFVO.'], isTrue);
    expect(labels[r'U$s'], isTrue);
    expect(labels['DEBITO'], isFalse);
    expect(labels['PESOS'], isTrue);
    expect(s.hasUsdTotal, isTrue);
    expect(s.hasArsTotal, isTrue);
  });

  test('creditCardChecks marca la cuota elegida', () {
    final s = PresupuestoSummary(_budget(const [
      PaymentAllocation(
          method: PaymentMethod.tarjeta6, amountUsd: 0, amountArs: 100),
    ]));
    final labels = {for (final c in s.creditCardChecks) c.label: c.checked};
    expect(labels['6 CTAS'], isTrue);
    expect(labels['1 CTA'], isFalse);
    expect(s.usesPesos, isTrue); // las cuotas de tarjeta se pagan en pesos
  });

  test('paymentAllocationLines formatea etiqueta y monto', () {
    final s = PresupuestoSummary(_budget(const [
      PaymentAllocation(
          method: PaymentMethod.efectivo, amountUsd: 0, amountArs: 100),
    ]));
    final line = s.paymentAllocationLines.single;
    expect(line.label, PaymentMethod.efectivo.label.toUpperCase());
    expect(line.amount, contains(r'$'));
  });
}
