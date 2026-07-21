import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  static bool _initialized = false;

  static bool get isConfigured => AppConfig.useSupabase;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!AppConfig.useSupabase || _initialized) return;

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static String? publicPhotoUrl(String path) {
    if (path.isEmpty || !isConfigured) return null;

    return client.storage.from(AppConfig.productPhotosBucket).getPublicUrl(path);
  }
}
