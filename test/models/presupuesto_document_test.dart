import 'package:app_feria/models/budget.dart';
import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/presupuesto_document.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:flutter_test/flutter_test.dart';

Budget _sampleBudget() {
  return Budget(
    date: DateTime(2026, 7, 22),
    customer: const BudgetCustomer(
      fullName: 'JUAN PEREZ',
      dni: '12345678',
    ),
    lines: const [
      BudgetLine(
        lineKey: 'line-1',
        productId: 'p1',
        code: 'M001',
        quantity: 2,
        detail: 'TEST · M001 · Cal. 9MM',
        unitArs: 150000,
        lineArs: 300000,
        unitUsd: 100,
        lineUsd: 200,
        paymentMethod: PaymentMethod.transferencia,
        isArma: false,
      ),
    ],
    totalUsd: 200,
    totalArs: 300000,
    paymentAllocations: const [
      PaymentAllocation(
        method: PaymentMethod.transferencia,
        amountUsd: 0,
        amountArs: 300000,
      ),
    ],
  );
}

void main() {
  test('pads table rows to paperRows for world guns', () {
    final document = PresupuestoDocument.fromBudget(
      _sampleBudget(),
      branding: PresupuestoBranding.worldGuns,
    );

    expect(document.tableRows, hasLength(PresupuestoBranding.worldGuns.paperRows));
    expect(document.tableRows.first.code, 'M001');
    expect(document.tableRows[1].isEmpty, isTrue);
  });

  test('pads table rows to urban paperRows', () {
    final document = PresupuestoDocument.fromBudget(
      _sampleBudget(),
      branding: PresupuestoBranding.urbanTactical,
    );

    expect(
      document.tableRows,
      hasLength(PresupuestoBranding.urbanTactical.paperRows),
    );
  });

  test('formats date parts and summary', () {
    final document = PresupuestoDocument.fromBudget(
      _sampleBudget(),
      branding: PresupuestoBranding.worldGuns,
    );

    expect(document.day, '22');
    expect(document.month, '07');
    expect(document.year, '2026');
    expect(document.summary.paymentAllocationLines, hasLength(1));
    expect(document.summary.primaryPaymentChecks.length, 5);
  });

  test('urban uses single-line formatted date', () {
    final document = PresupuestoDocument.fromBudget(
      _sampleBudget(),
      branding: PresupuestoBranding.urbanTactical,
    );

    expect(document.formattedDate, '22 jul 2026');
  });

  test('includes serial in detailWithSerial', () {
    final budget = Budget(
      date: DateTime(2026, 7, 22),
      customer: const BudgetCustomer(),
      lines: const [
        BudgetLine(
          lineKey: 'arma-1',
          productId: 'p2',
          code: 'A001',
          quantity: 1,
          detail: 'MARCA · MODELO · Cal. 9MM',
          unitArs: 500000,
          lineArs: 500000,
          unitUsd: 300,
          lineUsd: 300,
          paymentMethod: PaymentMethod.transferencia,
          isArma: true,
          serialNumber: 'ABC123',
        ),
      ],
      totalUsd: 300,
      totalArs: 500000,
    );

    final row = PresupuestoItemRow.fromLine(budget.lines.first);
    expect(row.detailWithSerial, contains('SERIE: ABC123'));
  });

  test('world guns table headers include TC between detalle and unit price', () {
    expect(PresupuestoBranding.worldGuns.tableHeaders, [
      'COD',
      'CANT',
      'DETALLE',
      'TC',
      'P. UNIT',
      'IMPORTE',
    ]);
  });

  test('urban table headers are concepto/cant/valor', () {
    expect(PresupuestoBranding.urbanTactical.tableHeaders, [
      'Concepto',
      'Cant',
      'Valor',
    ]);
  });

  test('resolves branding by tenant slug', () {
    expect(
      PresupuestoBranding.forTenant(slug: 'world-guns').kind,
      PresupuestoTemplateKind.worldGuns,
    );
    expect(
      PresupuestoBranding.forTenant(slug: 'urban-tactical').kind,
      PresupuestoTemplateKind.urbanTactical,
    );
    final generic = PresupuestoBranding.forTenant(
      slug: 'nueva-armeria',
      displayName: 'Nueva Armería',
    );
    expect(generic.kind, PresupuestoTemplateKind.standard);
    expect(generic.companyName, 'NUEVA ARMERÍA');
  });

  test('TC muestra tarjeta de consumo por línea', () {
    final budget = _sampleBudget().copyWithCustomer(const BudgetCustomer());
    final line = budget.lines.first;
    final row = PresupuestoItemRow.fromLine(
      BudgetLine(
        lineKey: line.lineKey,
        productId: line.productId,
        code: line.code,
        quantity: line.quantity,
        detail: line.detail,
        unitArs: line.unitArs,
        lineArs: line.lineArs,
        unitUsd: line.unitUsd,
        lineUsd: line.lineUsd,
        paymentMethod: line.paymentMethod,
        isArma: line.isArma,
        tarjetaConsumo: '1234567',
      ),
    );
    expect(row.tc, '1234567');
  });
}
