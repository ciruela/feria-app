import 'package:app_feria/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // No hay salida observable (usa developer.log); verificamos que no arroje
  // y que ejercite todos los niveles.
  test('todos los niveles se ejecutan sin lanzar', () {
    expect(() => AppLogger.info('hola'), returnsNormally);
    expect(() => AppLogger.warn('cuidado'), returnsNormally);
    expect(
      () => AppLogger.warn('con error', error: Exception('x'),
          stackTrace: StackTrace.current),
      returnsNormally,
    );
    expect(
      () => AppLogger.error('grave', error: Exception('y'),
          stackTrace: StackTrace.current),
      returnsNormally,
    );
  });
}
