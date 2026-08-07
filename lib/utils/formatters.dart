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
  return formatter.format(dateTime);
}

String formatDate(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(date);
}

String formatTime(DateTime dateTime) {
  return DateFormat('HH:mm').format(dateTime);
}

String formatSellerFirstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return fullName.trim();
  final first = parts.first.toLowerCase();
  return first[0].toUpperCase() + first.substring(1);
}
