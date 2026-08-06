import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';

/// Observabilidad de producción (AR-19).
///
/// Si `SENTRY_DSN` está vacío, no inicializa Sentry: igual quedan
/// `AppLogger.warn/error` en release y handlers de error de Flutter.
class Telemetry {
  Telemetry._();

  static bool _sentryReady = false;

  static bool get isEnabled => _sentryReady;

  static Future<void> init(FutureOr<void> Function() appRunner) async {
    _installFlutterHooks();

    final dsn = AppConfig.sentryDsn.trim();
    if (dsn.isEmpty) {
      AppLogger.info('Sentry deshabilitado (sin SENTRY_DSN)');
      await appRunner();
      return;
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = kReleaseMode ? 'production' : 'debug';
        options.release = AppConfig.releaseLabel;
        options.dist = AppConfig.gitSha.isEmpty ? null : AppConfig.gitSha;
        options.sendDefaultPii = false;
        options.tracesSampleRate = 0.0;
      },
      appRunner: () async {
        _sentryReady = true;
        AppLogger.reporter = _reportToSentry;
        await appRunner();
      },
    );
  }

  /// Llamar después de [SupabaseService.initialize].
  static void bindAuth() {
    if (!_sentryReady || !AppConfig.useSupabase) return;
    _syncAuthContext(Supabase.instance.client.auth.currentSession);
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _syncAuthContext(data.session);
    });
  }

  static void setTenant(String? tenantId) {
    if (!_sentryReady) return;
    final id = tenantId?.trim();
    Sentry.configureScope((scope) {
      if (id == null || id.isEmpty) {
        scope.removeTag('tenant_id');
      } else {
        scope.setTag('tenant_id', id);
      }
    });
  }

  static void _installFlutterHooks() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      AppLogger.error(
        details.exceptionAsString(),
        error: details.exception,
        stackTrace: details.stack,
      );
      previous?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('Error no capturado', error: error, stackTrace: stack);
      if (_sentryReady) {
        Sentry.captureException(error, stackTrace: stack);
      }
      return true;
    };
  }

  static void _syncAuthContext(Session? session) {
    if (!_sentryReady) return;
    Sentry.configureScope((scope) {
      if (session == null) {
        scope.setUser(null);
        scope.removeTag('tenant_id');
        return;
      }
      scope.setUser(SentryUser(id: session.user.id));
      final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
      final tenantId = (claim is String ? claim : claim?.toString())?.trim();
      if (tenantId != null && tenantId.isNotEmpty) {
        scope.setTag('tenant_id', tenantId);
      }
    });
  }

  static void _reportToSentry(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final sentryLevel =
        level == 'ERROR' ? SentryLevel.error : SentryLevel.warning;
    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = sentryLevel;
          scope.setContexts('app_logger', {'message': message});
        },
      );
    } else {
      Sentry.captureMessage(message, level: sentryLevel);
    }
  }
}
