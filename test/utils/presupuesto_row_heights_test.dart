import 'package:flutter_test/flutter_test.dart';

import 'package:app_feria/models/presupuesto_document.dart';
import 'package:app_feria/utils/presupuesto_row_heights.dart';

PresupuestoItemRow _arma(String key) => PresupuestoItemRow(
      lineKey: key,
      code: 'A1',
      quantity: 1,
      detail: 'Pistola',
      tc: '',
      unitPrice: '100',
      lineTotal: '100',
      isArma: true,
      serialNumber: 'SN',
    );

PresupuestoItemRow _normal(String key) => PresupuestoItemRow(
      lineKey: key,
      code: 'M1',
      quantity: 1,
      detail: 'Municion',
      tc: '',
      unitPrice: '10',
      lineTotal: '10',
      isArma: false,
    );

void main() {
  group('PresupuestoRowHeights', () {
    test('fits real rows into body without exceeding available height', () {
      final rows = [
        _arma('1'),
        _arma('2'),
        _normal('3'),
        const PresupuestoItemRow.empty(),
        const PresupuestoItemRow.empty(),
      ];
      const bodyHeight = 200.0;
      const header = 26.0;

      final heights = PresupuestoRowHeights.resolve(
        rows: rows,
        bodyHeight: bodyHeight,
        headerHeight: header,
        armaPref: 54,
        normalPref: 28,
        fillerPref: 22,
      );

      final used = heights.arma * 2 +
          heights.normal * 1 +
          heights.filler * 2 +
          header;
      expect(used, lessThanOrEqualTo(bodyHeight + 0.01));
      expect(heights.filler, greaterThanOrEqualTo(0));
    });

    test('scales down when preferred arma heights do not fit', () {
      final rows = [_arma('1'), _arma('2'), _arma('3'), _arma('4')];
      const bodyHeight = 120.0;
      const header = 22.0;

      final heights = PresupuestoRowHeights.resolve(
        rows: rows,
        bodyHeight: bodyHeight,
        headerHeight: header,
        armaPref: 54,
        normalPref: 28,
        fillerPref: 22,
      );

      expect(heights.filler, 0);
      expect(heights.arma * 4, lessThanOrEqualTo(bodyHeight - header + 0.01));
      expect(heights.arma, lessThan(54));
    });
  });
}
