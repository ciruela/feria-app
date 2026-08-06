/// Configuración de la app.
///
/// Supabase (recomendado): pasá URL y anon key al compilar:
/// ```
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// Alternativa legacy: JSON estático en Storage con CATALOG_URL / SELLERS_URL.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const catalogUrl = String.fromEnvironment(
    'CATALOG_URL',
    defaultValue: '',
  );

  static const sellersUrl = String.fromEnvironment(
    'SELLERS_URL',
    defaultValue: '',
  );

  /// DSN de Sentry (opcional). Vacío = sin telemetría remota.
  static const sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Commit del build (`GITHUB_SHA` en CI). Vacío en builds locales.
  static const gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: '',
  );

  /// Versión semántica del pubspec (inyectada en CI si hace falta).
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static String get releaseLabel {
    final sha = gitSha.trim();
    if (sha.isEmpty) return appVersion;
    final short = sha.length > 7 ? sha.substring(0, 7) : sha;
    return '$appVersion+$short';
  }

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get useCloudCatalog => !useSupabase && catalogUrl.isNotEmpty;

  static bool get useCloudSellers => !useSupabase && sellersUrl.isNotEmpty;

  static bool get usesRemoteCatalog => useSupabase || useCloudCatalog;

  static bool get usesRemoteSellers => useSupabase || useCloudSellers;

  static const productPhotosBucket = 'feria-fotos';
  static const comprobantesBucket = 'feria-comprobantes';
}
