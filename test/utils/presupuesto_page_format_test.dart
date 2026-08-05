import 'package:app_feria/utils/presupuesto_page_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A4 dimensions and inner area', () {
    expect(PresupuestoPageFormat.sheetWidth, closeTo(595.28, 0.01));
    expect(PresupuestoPageFormat.sheetHeight, closeTo(841.89, 0.01));
    expect(
      PresupuestoPageFormat.aspectRatio,
      closeTo(PresupuestoPageFormat.sheetWidth / PresupuestoPageFormat.sheetHeight, 0.001),
    );
    expect(
      PresupuestoPageFormat.innerWidth,
      PresupuestoPageFormat.sheetWidth -
          PresupuestoPageFormat.marginHorizontal * 2 -
          PresupuestoPageFormat.borderPadding * 2,
    );
    expect(
      PresupuestoPageFormat.innerHeight,
      PresupuestoPageFormat.sheetHeight -
          PresupuestoPageFormat.marginVertical * 2 -
          PresupuestoPageFormat.borderPadding * 2,
    );
  });
}
