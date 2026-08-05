import 'package:app_feria/models/budget.dart';
import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/presupuesto_branding.dart';
import 'package:app_feria/models/presupuesto_summary.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/models/urban_receipt_options.dart';
import 'package:flutter_test/flutter_test.dart';

Budget _budgetWithMethods(
  Set<PaymentMethod> methods, {
  List<PaymentAllocation>? allocations,
}) {
  final method = methods.first;
  return Budget(
    date: DateTime(2026, 7, 22),
    customer: const BudgetCustomer(fiscalCondition: 'Cons. final'),
    lines: [
      BudgetLine(
        lineKey: 'line-1',
        productId: 'p1',
        code: 'M001',
        quantity: 1,
        detail: 'TEST',
        unitArs: 100,
        lineArs: 100,
        unitUsd: 0,
        lineUsd: 0,
        paymentMethod: method,
        isArma: false,
      ),
    ],
    totalArs: 100,
    totalUsd: 0,
    paymentAllocations: allocations ?? const [],
  );
}

void main() {
  test('urban payment abbrev maps EF TR TC OTROS', () {
    final branding = PresupuestoBranding.urbanTactical;

    expect(
      PresupuestoSummary(
        _budgetWithMethods({PaymentMethod.efectivo}),
      ).paymentAbbrevFor(branding),
      'EF',
    );
    expect(
      PresupuestoSummary(
        _budgetWithMethods({PaymentMethod.transferencia}),
      ).paymentAbbrevFor(branding),
      'TR',
    );
    expect(
      PresupuestoSummary(
        _budgetWithMethods({PaymentMethod.tarjeta3}),
      ).paymentAbbrevFor(branding),
      'TC',
    );
    expect(
      PresupuestoSummary(
        _budgetWithMethods({PaymentMethod.debito}),
      ).paymentAbbrevFor(branding),
      'OTROS',
    );
  });

  test('urban dual EF+TR shows EF/TR', () {
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(),
      lines: const [],
      totalArs: 1000,
      totalUsd: 0,
      paymentAllocations: const [
        PaymentAllocation(
          method: PaymentMethod.efectivo,
          amountUsd: 0,
          amountArs: 400,
        ),
        PaymentAllocation(
          method: PaymentMethod.transferencia,
          amountUsd: 0,
          amountArs: 600,
        ),
      ],
    );

    expect(
      PresupuestoSummary(budget)
          .paymentAbbrevFor(PresupuestoBranding.urbanTactical),
      'EF/TR',
    );
  });

  test('urban fiscal condition defaults to Cons. final', () {
    const branding = PresupuestoBranding.urbanTactical;
    final summary = PresupuestoSummary(
      _budgetWithMethods({PaymentMethod.transferencia}),
    );

    expect(summary.fiscalConditionFor(branding), 'Cons. final');
  });

  test('urban domicilio combines address and city from DNI scan', () {
    const customer = BudgetCustomer(
      address: 'CALLE FALSA 123',
      city: 'PILAR',
    );

    expect(customer.domicilioLine, 'CALLE FALSA 123 · PILAR');
  });

  test('urban branding phone includes both numbers', () {
    expect(
      PresupuestoBranding.urbanTactical.phoneLine,
      contains('1168257250'),
    );
    expect(
      PresupuestoBranding.urbanTactical.phoneLine,
      contains('1126934666'),
    );
  });

  test('urban receipt options include payment and fiscal lists', () {
    expect(UrbanReceiptOptions.paymentMethods, contains('EF/TR'));
    expect(UrbanReceiptOptions.fiscalConditions, contains('Resp. Inscrip'));
  });
}
