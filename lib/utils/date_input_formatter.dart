import 'package:flutter/services.dart';

/// Formatea una fecha `dd/mm/aaaa` mientras se escribe: el usuario tipea solo
/// los dígitos y las barras se insertan solas (ej: `09032026` -> `09/03/2026`).
class DateTextInputFormatter extends TextInputFormatter {
  const DateTextInputFormatter();

  static const formatters = [DateTextInputFormatter()];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      // Barra después del día (posición 1) y del mes (posición 3), pero no
      // al final para no dejar una barra colgando mientras se escribe.
      if ((i == 1 || i == 3) && i != limited.length - 1) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
