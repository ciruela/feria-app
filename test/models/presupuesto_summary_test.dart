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

  test('standard payment abbrev and combined total', () {
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(),
      lines: const [
        BudgetLine(
          lineKey: 'l1',
          productId: 'p1',
          code: 'M1',
          quantity: 1,
          detail: 'Item',
          unitArs: 1000,
          lineArs: 1000,
          unitUsd: 10,
          lineUsd: 10,
          paymentMethod: PaymentMethod.efectivo,
          isArma: false,
        ),
      ],
      totalArs: 1000,
      totalUsd: 10,
      paymentAllocations: const [
        PaymentAllocation(
          method: PaymentMethod.efectivo,
          amountUsd: 0,
          amountArs: 1000,
        ),
        PaymentAllocation(
          method: PaymentMethod.dolarBillete,
          amountUsd: 10,
          amountArs: 0,
        ),
      ],
    );
    final summary = PresupuestoSummary(budget);

    expect(
      summary.paymentAbbrevFor(PresupuestoBranding.worldGuns),
      contains('EF'),
    );
    expect(summary.formattedCombinedTotal, contains('1.000'));
    expect(summary.formattedCombinedTotal, contains('10.00'));
    expect(summary.primaryPaymentChecks.first.checked, isTrue);
    expect(summary.paymentAllocationLines, isNotEmpty);
  });

  test('urban fiscal condition reads legacy email field', () {
    const branding = PresupuestoBranding.urbanTactical;
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(email: 'Resp. Inscrip'),
      lines: const [],
      totalArs: 0,
      totalUsd: 0,
    );

    expect(
      PresupuestoSummary(budget).fiscalConditionFor(branding),
      'Resp. Inscrip',
    );
  });

  test('urban multi-method abbrev joins unique codes', () {
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(),
      lines: const [],
      totalArs: 100,
      totalUsd: 0,
      paymentAllocations: const [
        PaymentAllocation(
          method: PaymentMethod.efectivo,
          amountUsd: 0,
          amountArs: 50,
        ),
        PaymentAllocation(
          method: PaymentMethod.tarjeta3,
          amountUsd: 0,
          amountArs: 50,
        ),
      ],
    );

    expect(
      PresupuestoSummary(budget)
          .paymentAbbrevFor(PresupuestoBranding.urbanTactical),
      'EF/TC',
    );
  });

  test('credit card checks reflect selected methods', () {
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(),
      lines: const [],
      totalArs: 100,
      totalUsd: 0,
      paymentAllocations: const [
        PaymentAllocation(
          method: PaymentMethod.tarjeta6,
          amountUsd: 0,
          amountArs: 50,
        ),
        PaymentAllocation(
          method: PaymentMethod.tarjeta12,
          amountUsd: 0,
          amountArs: 50,
        ),
      ],
    );
    final summary = PresupuestoSummary(budget);

    final checks = summary.creditCardChecks;
    expect(checks.firstWhere((c) => c.label == '6 CTAS').checked, isTrue);
    expect(checks.firstWhere((c) => c.label == '12 CTAS').checked, isTrue);
    expect(checks.firstWhere((c) => c.label == '1 CTA').checked, isFalse);
  });
}
