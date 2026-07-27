import 'dart:math';

final _random = Random();

/// Genera un ID globalmente unico con un prefijo legible.
///
/// En multi-tenant, los IDs de texto (admins, vendedores, productos) NO pueden
/// ser secuenciales por tenant (colisionarian entre armerias, ya que la PK es
/// global). Este generador combina timestamp + aleatorio para evitarlo.
String newId(String prefix) {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final rand = _random.nextInt(0x7fffffff).toRadixString(36);
  return '${prefix}_${micros.toRadixString(36)}$rand';
}
