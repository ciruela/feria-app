import 'package:app_feria/data/common_calibers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergedWith deduplicates and sorts', () {
    final merged = CommonCalibers.mergedWith(['9mm', '.22 LR', '9MM']);

    expect(merged.where((c) => c.toLowerCase() == '9mm'), hasLength(1));
    expect(merged, contains('.22 LR'));
    expect(merged, contains('9MM'));
    expect(merged.length, greaterThan(CommonCalibers.values.length - 1));
  });

  test('quickPick entries are in values', () {
    for (final calibre in CommonCalibers.quickPick) {
      expect(CommonCalibers.values, contains(calibre));
    }
  });
}
