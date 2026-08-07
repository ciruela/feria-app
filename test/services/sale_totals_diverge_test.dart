import 'package:app_feria/services/supabase_sales_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching totals do not diverge', () {
    expect(
      saleTotalsDiverge(
        serverArs: 2700000,
        serverUsd: 1800,
        clientArs: 2700000,
        clientUsd: 1800,
      ),
      isFalse,
    );
  });

  test('dollar-cash sale with zero ARS on both sides is fine', () {
    expect(
      saleTotalsDiverge(
        serverArs: 0,
        serverUsd: 900,
        clientArs: 0,
        clientUsd: 900,
      ),
      isFalse,
    );
  });

  test('USD drift is detected even when ARS is zero', () {
    expect(
      saleTotalsDiverge(
        serverArs: 0,
        serverUsd: 900,
        clientArs: 0,
        clientUsd: 1000,
      ),
      isTrue,
    );
  });

  test('ARS drift beyond 1 peso is detected', () {
    expect(
      saleTotalsDiverge(
        serverArs: 2700000,
        serverUsd: 1800,
        clientArs: 2970000,
        clientUsd: 1800,
      ),
      isTrue,
    );
  });

  test('sub-centavo rounding noise is tolerated', () {
    expect(
      saleTotalsDiverge(
        serverArs: 1000.50,
        serverUsd: 10.0001,
        clientArs: 1000.00,
        clientUsd: 10.0,
      ),
      isFalse,
    );
  });

  test('many lines of sub-cent rounding still within tolerance', () {
    // Server rounds each allocation; client uses raw doubles.
    // Accumulated noise for a large cart should stay under $1 / USD 0.01.
    expect(
      saleTotalsDiverge(
        serverArs: 150000.15,
        serverUsd: 100.005,
        clientArs: 150000.00,
        clientUsd: 100.0,
      ),
      isFalse,
    );
  });
}
