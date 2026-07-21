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

String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('dd/MM/yyyy - HH:mm');
  return formatter.format(dateTime);
}

String formatDate(DateTime date) {
  final formatter = DateFormat('dd/MM/yyyy');
  return formatter.format(date);
}
