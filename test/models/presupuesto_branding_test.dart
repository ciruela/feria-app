import 'package:app_feria/models/presupuesto_branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard template uses tenant display name and initials logo', () {
    final branding = PresupuestoBranding.standard('Mi Armería Test');

    expect(branding.kind, PresupuestoTemplateKind.standard);
    expect(branding.companyName, 'MI ARMERÍA TEST');
    expect(branding.logoText, 'MA');
    expect(branding.showsDetailedTable, isTrue);
    expect(branding.showsPaymentChecks, isTrue);
  });

  test('urban template hides payment checks and detailed table', () {
    const branding = PresupuestoBranding.urbanTactical;

    expect(branding.showsDetailedTable, isFalse);
    expect(branding.showsPaymentChecks, isFalse);
    expect(branding.useSingleDateLine, isTrue);
  });
}
