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

  test('formatDateTime convierte UTC a hora local', () {
    final utc = DateTime.utc(2026, 3, 9, 17, 5);
    final local = utc.toLocal();
    final expected =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} - '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    expect(formatDateTime(utc), expected);
  });

  test('formatSignedArsDelta shows surcharge and discount', () {
    expect(formatSignedArsDelta(1200), '+ \$ 1.200');
    expect(formatSignedArsDelta(-500), '- \$ 500');
    expect(formatSignedArsDelta(0.1), isNull);
  });

  test('formatSignedUsdDelta shows surcharge and discount', () {
    expect(formatSignedUsdDelta(10), '+ USD 10.00');
    expect(formatSignedUsdDelta(-2.5), '- USD 2.50');
    expect(formatSignedUsdDelta(0.001), isNull);
  });

  test('parseExchangeRate accepts comma and point decimals (AR-37)', () {
    expect(parseExchangeRate('1500.50'), 1500.50);
    expect(parseExchangeRate('1500,50'), 1500.50);
    expect(parseExchangeRate('1.500,50'), 1500.50);
    expect(parseExchangeRate('1,500.50'), 1500.50);
    expect(parseExchangeRate('1500'), 1500);
    expect(parseExchangeRate(''), isNull);
  });

  test('formatExchangeRate keeps cents', () {
    expect(formatExchangeRate(1500.5), contains('50'));
    expect(formatExchangeRateInput(1500.5), '1500.5');
    expect(formatExchangeRateInput(1500.50), anyOf('1500.5', '1500.50'));
    expect(formatExchangeRateInput(1500), '1500');
  });
}
