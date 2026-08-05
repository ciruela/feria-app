import '../config/app_config.dart';
import 'supabase_service.dart';

/// Registra el subdominio web del tenant en Cloudflare Pages (best-effort).
class TenantSubdomainService {
  Future<void> registerForCurrentTenant() async {
    if (!AppConfig.useSupabase) return;

    try {
      await SupabaseService.client.functions.invoke(
        'register-tenant-subdomain',
      );
    } catch (_) {
      // No bloquea el registro si Cloudflare falla; el admin puede reintentar.
    }
  }
}
