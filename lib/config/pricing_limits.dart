/// Espejo exacto de `public._sale_clamp_pct` en la migración de register_sale.
/// Si esto cambia, cambia también `_sale_clamp_pct` en una migración nueva.
/// Nunca uno solo de los dos lados.
class PricingLimits {
  static const efectivoMax = 30.0;
  static const recargoMax = 100.0;
  static const min = 0.0;

  static (double, double) rangeFor(String key) =>
      key == 'efectivo' ? (min, efectivoMax) : (min, recargoMax);

  static double clamp(String key, double value) {
    final (lo, hi) = rangeFor(key);
    return value.clamp(lo, hi).toDouble();
  }
}
