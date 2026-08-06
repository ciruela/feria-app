import 'dart:async';

import 'package:app_feria/utils/retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('withTimeoutRetry reintenta errores de red y luego ok', () async {
    var attempts = 0;
    final result = await withTimeoutRetry(
      () async {
        attempts++;
        if (attempts < 3) {
          throw Exception('SocketException: connection reset');
        }
        return 'ok';
      },
      timeout: const Duration(seconds: 2),
      maxAttempts: 3,
      initialDelay: Duration.zero,
      operation: 'test',
    );
    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('withTimeoutRetry no reintenta errores de negocio', () async {
    var attempts = 0;
    await expectLater(
      () => withTimeoutRetry(
        () async {
          attempts++;
          throw StateError('insufficient_stock');
        },
        maxAttempts: 3,
        initialDelay: Duration.zero,
        operation: 'test',
      ),
      throwsA(isA<StateError>()),
    );
    expect(attempts, 1);
  });

  test('timeout cuenta como transitorio', () {
    expect(isTransientNetworkError(TimeoutException('x')), isTrue);
  });
}
