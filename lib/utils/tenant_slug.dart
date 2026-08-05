/// Detecta el slug del tenant desde la URL (solo relevante en web).
///
/// Soporta:
///   - subdominio:  worldguns.armenext.com  -> "worldguns"
///   - query param: armenext.com/?tenant=world-guns -> "world-guns"
///   - primer path: armenext.com/worldguns -> "worldguns"
///
/// El slug de la URL puede omitir guiones (`urbantactical` = `urban-tactical` en DB).
/// El aislamiento real de datos lo da Supabase Auth + RLS, no la URL.

/// Dominio base de la app web en producción.
const tenantAppDomain = 'armenext.com';

const _reservedHostLabels = {
  'www',
  'app',
  'localhost',
  'admin',
  'api',
  'auth',
  'login',
};

String? detectTenantSlug() {
  final uri = Uri.base;

  final fromQuery = uri.queryParameters['tenant']?.trim();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  final host = uri.host.toLowerCase();
  if (host == tenantAppDomain || host == 'www.$tenantAppDomain') {
    return null;
  }

  final parts = host.split('.');
  if (parts.length >= 3 && !_reservedHostLabels.contains(parts.first)) {
    return parts.first;
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && !_reservedHostLabels.contains(segments.first)) {
    return segments.first;
  }

  return null;
}

/// Clave normalizada para comparar slugs con o sin guiones.
String tenantSlugKey(String slug) =>
    slug.trim().toLowerCase().replaceAll('-', '');

/// Subdominio público de una armería (sin guiones).
String tenantSlugToSubdomain(String slug) => tenantSlugKey(slug);

/// URL web del panel de una armería.
String tenantPortalUrl(String slug) {
  final host = tenantSlugToSubdomain(slug);
  if (host.isEmpty) return 'https://app.$tenantAppDomain';
  return 'https://$host.$tenantAppDomain';
}

bool tenantSlugMatches(String a, String b) =>
    tenantSlugKey(a) == tenantSlugKey(b);

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
  const reserved = {
    'admin',
    'app',
    'api',
    'www',
    'default',
    'platform',
    'auth',
    'login',
  };
  if (reserved.contains(s)) return '$s-shop';
  return s;
}

/// Presentación legible de un slug (world-guns → World Guns).
String humanizeTenantSlug(String slug) {
  final key = tenantSlugKey(slug);
  if (key.isEmpty) return 'Armería';

  if (!slug.contains('-') && !slug.contains('_')) {
    return key[0].toUpperCase() + key.substring(1);
  }

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
