/// Clasifica munición como de arma larga vs corta según calibre/descripción.
///
/// Usado por promos (p. ej. World Guns: 3 cuotas SI solo en munición larga).
/// Heurística: si matchea un calibre típico de pistola/revólver → corta;
/// el resto (rifle, escopeta, .22, vacío) → larga.
bool isMunicionArmaLarga({
  required String calibre,
  String descripcion = '',
}) {
  return !isMunicionArmaCorta(calibre: calibre, descripcion: descripcion);
}

/// True si el texto apunta a munición de arma corta (pistola / revólver).
bool isMunicionArmaCorta({
  required String calibre,
  String descripcion = '',
}) {
  final haystack = _normalizeCalibreText('$calibre $descripcion');
  if (haystack.isEmpty) return false;

  for (final pattern in _handgunCalibrePatterns) {
    if (pattern.hasMatch(haystack)) return true;
  }
  return false;
}

String _normalizeCalibreText(String raw) {
  var s = raw
      .replaceAll('\u00a0', ' ')
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');
  // Unificar separadores: ".9 mm" / "9x19" / "C.9" → tokens comparables.
  s = s.replaceAll(RegExp(r'[^a-z0-9.x/]+'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Patrones de calibres de arma corta (orden: más específicos primero).
final List<RegExp> _handgunCalibrePatterns = [
  // 9 mm familia (no 9.3x62 rifle).
  RegExp(r'(^| )(c\.?\s*)?\.?9(mm|x19|x21|x18| para|mm para)?( |$)'),
  RegExp(r'(^| )9\s*mm( |$)'),
  RegExp(r'(^| )9\s*x\s*19( |$)'),
  // .380 / 9 corto
  RegExp(r'(^| )(c\.?\s*)?\.?380(acp| auto)?( |$)'),
  RegExp(r'(^| )9\s*corto( |$)'),
  // .45 ACP / Auto (evitar .450/.458 rifle si el token es exacto)
  RegExp(r'(^| )(c\.?\s*)?\.?45(\s*(acp|auto))?(\.0+)?( |$)'),
  // .40 S&W
  RegExp(r'(^| )(c\.?\s*)?\.?40(\s*(s.?w|sw))?(\.0+)?( |$)'),
  // .38 Special / .38
  RegExp(r'(^| )(c\.?\s*)?\.?38(\s*special|\s*spl)?(\.0+)?( |$)'),
  // .357 Mag
  RegExp(r'(^| )(c\.?\s*)?\.?357(\s*mag(num)?)?(\.0+)?( |$)'),
  // .44 Mag / Special
  RegExp(r'(^| )(c\.?\s*)?\.?44(\s*(mag(num)?|special|spl))?(\.0+)?( |$)'),
  // .32 ACP / 7.65
  RegExp(r'(^| )(c\.?\s*)?\.?32(\s*(acp|auto))?(\.0+)?( |$)'),
  RegExp(r'(^| )7\.65( |$)'),
  // .25 ACP / 6.35
  RegExp(r'(^| )(c\.?\s*)?\.?25(\s*(acp|auto))?(\.0+)?( |$)'),
  RegExp(r'(^| )6\.35( |$)'),
  // 10mm Auto
  RegExp(r'(^| )10\s*mm( |$)'),
  // .41 Mag (revólver)
  RegExp(r'(^| )(c\.?\s*)?\.?41(\s*mag(num)?)?(\.0+)?( |$)'),
  // .50 AE (Desert Eagle) — no .50 BMG
  RegExp(r'(^| )(c\.?\s*)?\.?50(\s*(ae|action express))( |$)'),
];
