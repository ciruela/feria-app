import 'package:app_feria/config/pricing_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('efectivo range is 0..30', () {
    expect(PricingLimits.rangeFor('efectivo'), (0.0, 30.0));
  });

  test('recargo ranges are 0..100', () {
    for (final key in [
      'debito',
      'tarjeta1',
      'tarjeta3',
      'tarjeta6',
      'tarjeta9',
      'tarjeta12',
      'tarjeta18',
    ]) {
      expect(PricingLimits.rangeFor(key), (0.0, 100.0), reason: key);
    }
  });

  test('clamp mirrors server bounds', () {
    expect(PricingLimits.clamp('efectivo', -10), 0);
    expect(PricingLimits.clamp('efectivo', 5), 5);
    expect(PricingLimits.clamp('efectivo', 30), 30);
    expect(PricingLimits.clamp('efectivo', 40), 30);

    expect(PricingLimits.clamp('tarjeta18', -1), 0);
    expect(PricingLimits.clamp('tarjeta18', 45), 45);
    expect(PricingLimits.clamp('tarjeta18', 120), 100);
  });
}
