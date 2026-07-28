import '../models/seller.dart';
import 'supabase_service.dart';

class SellerPortalValidation {
  const SellerPortalValidation({
    required this.tenantId,
    required this.tenantNombre,
    required this.tenantSlug,
    required this.sellers,
  });

  final String tenantId;
  final String tenantNombre;
  final String tenantSlug;
  final List<Seller> sellers;
}

class SellerPortalLoginResult {
  const SellerPortalLoginResult({
    required this.tenantId,
    required this.tenantNombre,
    required this.sellerId,
    required this.sellerNombre,
  });

  final String tenantId;
  final String tenantNombre;
  final String sellerId;
  final String sellerNombre;
}

class SellerPortalService {
  Future<SellerPortalValidation> validatePortal({
    required String slug,
    required String codigo,
  }) async {
    final raw = await SupabaseService.client.rpc(
      'validate_seller_portal',
      params: {
        'p_slug': slug.trim(),
        'p_codigo': codigo.trim(),
      },
    );

    final map = raw as Map<String, dynamic>;
    final sellersJson = map['sellers'] as List<dynamic>? ?? const [];

    return SellerPortalValidation(
      tenantId: map['tenant_id'] as String,
      tenantNombre: map['tenant_nombre'] as String? ?? '',
      tenantSlug: map['tenant_slug'] as String? ?? slug.trim(),
      sellers: sellersJson
          .map(
            (item) => Seller(
              id: (item as Map<String, dynamic>)['id'] as String,
              nombre: item['nombre'] as String? ?? '',
            ),
          )
          .toList(),
    );
  }

  Future<SellerPortalLoginResult> completeLogin({
    required String slug,
    required String codigo,
    required String sellerId,
  }) async {
    final raw = await SupabaseService.client.rpc(
      'complete_seller_portal_login',
      params: {
        'p_slug': slug.trim(),
        'p_codigo': codigo.trim(),
        'p_seller_id': sellerId,
      },
    );

    final map = raw as Map<String, dynamic>;
    return SellerPortalLoginResult(
      tenantId: map['tenant_id'] as String,
      tenantNombre: map['tenant_nombre'] as String? ?? '',
      sellerId: map['seller_id'] as String,
      sellerNombre: map['seller_nombre'] as String? ?? '',
    );
  }

  Future<void> setPortalCode(String codigo) async {
    await SupabaseService.client.rpc(
      'set_seller_portal_code',
      params: {'p_codigo': codigo.trim()},
    );
  }

  Future<String?> fetchCurrentTenantSlug() async {
    final raw = await SupabaseService.client.rpc('current_tenant_slug');
    if (raw == null) return null;
    final slug = raw.toString().trim();
    return slug.isEmpty ? null : slug;
  }
}
