import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Callback opcional para telemetría (p.ej. Sentry).
typedef AppLogReporter = void Function(
  String level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// Logger central de la app.
///
/// AR-19: en release emite `warn`/`error` (antes era no-op total vía
/// `kDebugMode` y dart2js eliminaba el código). `info` sigue solo en debug.
class AppLogger {
  const AppLogger._();

  /// Sink remoto (Sentry u otro). Se asigna desde [Telemetry].
  static AppLogReporter? reporter;

  static void warn(String message, {Object? error, StackTrace? stackTrace}) {
    _log('WARN', message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  static void info(String message) {
    _log('INFO', message);
  }

  static void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final isError = level == 'ERROR';
    final isWarn = level == 'WARN';
    // info solo debug; warn/error también en release.
    if (!kDebugMode && !isError && !isWarn) return;

    developer.log(
      message,
      name: 'feria.$level',
      error: error,
      stackTrace: stackTrace,
      level: isError ? 1000 : (isWarn ? 900 : 800),
    );

    if (!kDebugMode && (isError || isWarn)) {
      reporter?.call(
        level,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
