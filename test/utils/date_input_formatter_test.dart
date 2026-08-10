import 'package:app_feria/utils/date_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = DateTextInputFormatter();

  TextEditingValue format(String oldText, String newText) {
    return formatter.formatEditUpdate(
      TextEditingValue(text: oldText),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );
  }

  test('inserta barras al tipear solo dígitos', () {
    expect(format('', '0').text, '0');
    expect(format('0', '09').text, '09');
    expect(format('09', '093').text, '09/3');
    expect(format('09/3', '0903').text, '09/03');
    expect(format('09/03', '09030').text, '09/03/0');
    expect(format('09/03/202', '090320').text, '09/03/20');
    expect(format('09/03/20', '09032026').text, '09/03/2026');
  });

  test('ignora caracteres no numéricos', () {
    expect(format('', '09/03/2026').text, '09/03/2026');
    expect(format('', 'ab12cd').text, '12');
  });

  test('limita a 8 dígitos (dd/mm/aaaa)', () {
    expect(format('', '0903202699').text, '09/03/2026');
  });

  test('el borrado remueve la barra correctamente', () {
    expect(format('09/03', '09/0').text, '09/0');
    expect(format('09/0', '09/').text, '09');
    expect(format('09', '0').text, '0');
  });

  test('cursor queda al final', () {
    final result = format('09/03', '09032026');
    expect(result.selection.baseOffset, result.text.length);
  });
}
