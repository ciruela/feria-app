import 'dart:async';
import 'dart:math';

import 'app_logger.dart';

/// Ejecuta [action] con timeout y reintentos con backoff exponencial + jitter.
///
/// Solo reintenta errores que [isTransient] clasifica como recuperables.
Future<T> withTimeoutRetry<T>(
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 20),
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 400),
  bool Function(Object error)? isTransient,
  String operation = 'request',
}) async {
  final transient = isTransient ?? isTransientNetworkError;
  Object? lastError;
  StackTrace? lastStack;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action().timeout(timeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStack = stackTrace;
      final canRetry = attempt < maxAttempts && transient(error);
      if (!canRetry) break;

      final delay = _backoffDelay(initialDelay, attempt);
      AppLogger.warn(
        'Reintento $operation ($attempt/$maxAttempts) en ${delay.inMilliseconds}ms',
        error: error,
        stackTrace: stackTrace,
      );
      await Future<void>.delayed(delay);
    }
  }

  Error.throwWithStackTrace(
    lastError ?? StateError('$operation falló'),
    lastStack ?? StackTrace.current,
  );
}

Duration _backoffDelay(Duration initial, int attempt) {
  final exp = initial.inMilliseconds * pow(2, attempt - 1).toInt();
  final jitter = Random().nextInt(200);
  return Duration(milliseconds: exp + jitter);
}

bool isTransientNetworkError(Object error) {
  if (error is TimeoutException) return true;
  final message = error.toString().toLowerCase();
  return message.contains('socket') ||
      message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('network') ||
      message.contains('connection') ||
      message.contains('clientexception') ||
      message.contains('failed host lookup');
}
