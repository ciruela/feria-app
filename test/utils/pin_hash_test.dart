import 'package:app_feria/utils/pin_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hashPin es determinista y no devuelve el PIN en claro', () {
    final h = hashPin('1234');
    expect(h, hashPin('1234'));
    expect(h, isNot('1234'));
    expect(isHashedPin(h), isTrue);
  });

  test('PINs distintos dan hashes distintos', () {
    expect(hashPin('1234'), isNot(hashPin('5678')));
  });

  test('pinMatches contra hash almacenado', () {
    final stored = hashPin('2580');
    expect(pinMatches('2580', stored), isTrue);
    expect(pinMatches('0000', stored), isFalse);
  });

  test('pinMatches soporta datos legados en texto plano', () {
    expect(pinMatches('2580', '2580'), isTrue);
    expect(pinMatches('1111', '2580'), isFalse);
  });
}
