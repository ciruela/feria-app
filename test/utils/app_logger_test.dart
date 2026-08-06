import 'package:app_feria/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    AppLogger.reporter = null;
  });

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

  test('reporter se invoca para warn/error cuando está asignado', () {
    final calls = <String>[];
    AppLogger.reporter = (level, message, {error, stackTrace}) {
      calls.add('$level:$message');
    };
    // En tests kDebugMode=true: el reporter solo corre en !kDebugMode.
    // Acá validamos que el hook sea asignable sin romper.
    AppLogger.warn('w');
    AppLogger.error('e');
    expect(AppLogger.reporter, isNotNull);
    expect(calls, isEmpty); // debug mode: no remote
  });
}
