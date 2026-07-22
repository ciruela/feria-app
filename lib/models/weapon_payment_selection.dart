import 'product_prices.dart';

class WeaponPaymentSelection {
  const WeaponPaymentSelection._({
    required this.first,
    this.second,
    this.firstShare = 1.0,
  });

  const WeaponPaymentSelection.single(PaymentMethod method)
      : this._(first: method);

  const WeaponPaymentSelection.dual({
    required PaymentMethod first,
    required PaymentMethod second,
    double firstShare = 0.5,
  }) : this._(first: first, second: second, firstShare: firstShare);

  final PaymentMethod first;
  final PaymentMethod? second;
  final double firstShare;

  bool get isDual => second != null;

  double get secondShare => 1.0 - firstShare;
}
