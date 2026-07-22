import 'package:flutter/services.dart';

/// Convierte el texto ingresado a mayúsculas mientras se escribe.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  static const formatters = [UpperCaseTextFormatter()];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
