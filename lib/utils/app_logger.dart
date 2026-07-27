import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logger central de la app. Evita `print` (bloqueado por lint) y `catch (_)`
/// silenciosos: registra en consola de debug y en el timeline de DevTools.
///
/// Uso:
///   AppLogger.warn('No se pudo guardar en nube', error: e, stackTrace: s);
class AppLogger {
  const AppLogger._();

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
    if (!kDebugMode) return;
    developer.log(
      message,
      name: 'feria.$level',
      error: error,
      stackTrace: stackTrace,
      level: level == 'ERROR' ? 1000 : 900,
    );
  }
}
