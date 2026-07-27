import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash de PINs de administrador/vendedor. Los PINs se guardan hasheados en la
/// base (nunca en texto plano). Como los PINs son cortos, el hash es un
/// endurecimiento adicional sobre la RLS (que ya impide que otro tenant los lea),
/// no la unica defensa.
const _pinSalt = 'feria-armeria::pin::v1';

String hashPin(String pin) {
  final bytes = utf8.encode('$_pinSalt$pin');
  return sha256.convert(bytes).toString();
}

/// Un valor guardado esta "hasheado" si es un SHA-256 en hex (64 chars).
bool isHashedPin(String value) {
  if (value.length != 64) return false;
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

/// Compara un PIN ingresado contra el valor almacenado, soportando datos
/// legados en texto plano (pre-migracion).
bool pinMatches(String input, String stored) {
  final clean = input.trim();
  if (isHashedPin(stored)) return hashPin(clean) == stored;
  return clean == stored; // legacy plaintext
}
