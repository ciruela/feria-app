import 'package:intl/intl.dart';

final _usdFormatter = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'USD ',
  decimalDigits: 2,
);

final _arsFormatter = NumberFormat.currency(
  locale: 'es_AR',
  symbol: r'$ ',
  decimalDigits: 0,
);

String formatUsd(double value) => _usdFormatter.format(value);

String formatArs(double value) => _arsFormatter.format(value);

/// AR-39: signed delta vs precio lista (`+ $ 1.200` / `- $ 500`). Null if ~0.
String? formatSignedArsDelta(double delta, {double epsilon = 0.5}) {
  if (delta.abs() < epsilon) return null;
  final abs = formatArs(delta.abs()).replaceFirst(r'$ ', '').trim();
  return delta > 0 ? '+ \$ $abs' : '- \$ $abs';
}

/// Signed USD delta vs lista. Null if ~0.
String? formatSignedUsdDelta(double delta, {double epsilon = 0.01}) {
  if (delta.abs() < epsilon) return null;
  final abs = formatUsd(delta.abs()).replaceFirst('USD ', '').trim();
  return delta > 0 ? '+ USD $abs' : '- USD $abs';
}

String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('dd/MM/yyyy - HH:mm');
  // Supabase/ISO llegan en UTC; formatear componentes UTC mostraba hora
  // corrida vs Argentina (AR-47).
  return formatter.format(dateTime.toLocal());
}

String formatDate(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(date.toLocal());
}

String formatTime(DateTime dateTime) {
  return DateFormat('HH:mm').format(dateTime.toLocal());
}

String formatSellerFirstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return fullName.trim();
  final first = parts.first.toLowerCase();
  return first[0].toUpperCase() + first.substring(1);
}

/// Tipo de cambio ARS/USD para UI (catálogo, presupuesto). Muestra centavos.
String formatExchangeRate(double rate) {
  return NumberFormat('#,##0.##', 'es_AR').format(rate);
}

/// Valor editable del TC: siempre con hasta 2 decimales (AR-37).
String formatExchangeRateInput(double rate) {
  if ((rate - rate.roundToDouble()).abs() < 0.0005) {
    return rate.round().toString();
  }
  final fixed = rate.toStringAsFixed(2);
  if (fixed.endsWith('0')) {
    return rate.toStringAsFixed(1);
  }
  return fixed;
}

/// Parsea TC aceptando coma o punto decimal (y miles AR/US).
double? parseExchangeRate(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'[\s\$]'), '');
  if (text.isEmpty) return null;

  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');

  if (lastDot >= 0 && lastComma >= 0) {
    if (lastComma > lastDot) {
      // 1.500,50
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else {
      // 1,500.50
      text = text.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final parts = text.split(',');
    if (parts.length == 2 && parts[1].length <= 2) {
      text = '${parts[0]}.${parts[1]}';
    } else {
      text = text.replaceAll(',', '');
    }
  } else if (lastDot >= 0) {
    final parts = text.split('.');
    if (parts.length == 2 && parts[1].length <= 2) {
      // 1500.5 / 1500.50 → decimal
    } else if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
      // 1.500 or 1.500.000 → thousands
      text = text.replaceAll('.', '');
    }
  }

  return double.tryParse(text);
}
