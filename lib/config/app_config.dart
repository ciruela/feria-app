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

  static bool get useSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get useCloudCatalog => !useSupabase && catalogUrl.isNotEmpty;

  static bool get useCloudSellers => !useSupabase && sellersUrl.isNotEmpty;

  static bool get usesRemoteCatalog => useSupabase || useCloudCatalog;

  static bool get usesRemoteSellers => useSupabase || useCloudSellers;

  static const productPhotosBucket = 'feria-fotos';
  static const comprobantesBucket = 'feria-comprobantes';
}
