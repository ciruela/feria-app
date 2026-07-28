/// Claves de cache local aisladas por armería (tenant).
String tenantCacheKey(String base, String? tenantId) {
  final id = tenantId?.trim();
  if (id == null || id.isEmpty) return base;
  return '${base}_$id';
}
