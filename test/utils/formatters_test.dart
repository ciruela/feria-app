import 'package:app_feria/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatUsd usa prefijo USD y 2 decimales', () {
    final s = formatUsd(1234.5);
    expect(s, contains('USD'));
    expect(s, contains('.50'));
  });

  test('formatArs usa símbolo \$ y sin decimales', () {
    final s = formatArs(150000);
    expect(s, contains(r'$'));
    expect(s.contains(','), isFalse);
  });

  test('formatDate dd/MM/yyyy', () {
    expect(formatDate(DateTime(2026, 3, 9)), '09/03/2026');
  });

  test('formatDateTime incluye hora', () {
    expect(formatDateTime(DateTime(2026, 3, 9, 14, 5)), '09/03/2026 - 14:05');
  });
}
