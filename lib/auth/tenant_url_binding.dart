import '../utils/tenant_slug.dart';

/// Super admin solo desde app.armenext.com (no en subdominios de armería).
bool platformAdminVisibleOnEntry({required bool isPlatformAdmin}) {
  return isPlatformAdmin && !isTenantSubdomainEntry();
}

/// Filtra memberships al tenant indicado por la URL (subdominio o ?tenant=).
List<T> filterByBoundTenantSlug<T>({
  required List<T> items,
  required String boundSlug,
  required String Function(T item) slugOf,
}) {
  final bound = boundSlug.trim();
  if (bound.isEmpty) return items;
  return items
      .where((item) => tenantSlugMatches(slugOf(item), bound))
      .toList(growable: false);
}

/// Slug de la URL cuando hay entrada restringida por tenant (subdominio real).
String? boundTenantSlugFromEntry() {
  if (!isTenantSubdomainEntry()) return null;
  return detectTenantSlug();
}
