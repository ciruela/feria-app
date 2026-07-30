/// Detecta el slug del tenant desde la URL (solo relevante en web).
///
/// Soporta:
///   - subdominio:  pepe.tuapp.com        -> "pepe"
///   - query param: tuapp.com/?tenant=pepe -> "pepe"
///   - primer path: tuapp.com/pepe        -> "pepe"
///
/// El slug es solo para branding/UX (mostrar de que armeria es el login). El
/// aislamiento real de datos lo da Supabase Auth + RLS, no la URL.
String? detectTenantSlug() {
  final uri = Uri.base;

  final fromQuery = uri.queryParameters['tenant']?.trim();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  final host = uri.host;
  const reserved = {'www', 'app', 'localhost', 'admin'};
  final parts = host.split('.');
  if (parts.length >= 3 && !reserved.contains(parts.first)) {
    return parts.first;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && !reserved.contains(segments.first)) {
    return segments.first;
  }

  return null;
}

/// Genera un slug legible a partir del nombre de la empresa (preview en registro).
String slugifyTenantName(String name) {
  var s = name.trim().toLowerCase();
  const from = 'áàäâãåéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaaeeeeiiiiooooouuuunc';
  for (var i = 0; i < from.length; i++) {
    s = s.replaceAll(from[i], to[i]);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) return 'armeria';
  const reserved = {'admin', 'app', 'api', 'www', 'default', 'platform', 'auth', 'login'};
  if (reserved.contains(s)) return '$s-shop';
  return s;
}

/// Presentación legible de un slug (world-guns → World Guns).
String humanizeTenantSlug(String slug) {
  return slug
      .trim()
      .split(RegExp(r'[-_\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
