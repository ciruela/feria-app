import 'dart:convert';

import 'package:crypto/crypto.dart';

const _portalSalt = 'feria-armeria::portal::v1';

String hashPortalCode(String code) {
  final bytes = utf8.encode('$_portalSalt${code.trim()}');
  return sha256.convert(bytes).toString();
}

bool portalCodeMatches(String input, String storedHash) {
  if (storedHash.isEmpty) return false;
  return hashPortalCode(input) == storedHash;
}
