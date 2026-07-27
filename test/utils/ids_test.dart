import 'package:app_feria/utils/ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newId usa el prefijo', () {
    expect(newId('a').startsWith('a_'), isTrue);
    expect(newId('prod').startsWith('prod_'), isTrue);
  });

  test('newId genera valores únicos', () {
    final ids = {for (var i = 0; i < 500; i++) newId('x')};
    expect(ids.length, 500);
  });
}
