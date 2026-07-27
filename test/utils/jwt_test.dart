import 'dart:convert';

import 'package:app_feria/utils/jwt.dart';
import 'package:flutter_test/flutter_test.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = enc({'alg': 'HS256', 'typ': 'JWT'});
  final body = enc(payload);
  return '$header.$body.signature';
}

void main() {
  group('decodeJwtPayload', () {
    test('lee claims de un JWT válido', () {
      final token = _fakeJwt({'tenant_id': 'world-guns', 'app_role': 'owner'});
      final claims = decodeJwtPayload(token);
      expect(claims['tenant_id'], 'world-guns');
      expect(claims['app_role'], 'owner');
    });

    test('token mal formado devuelve mapa vacío', () {
      expect(decodeJwtPayload('no-es-un-jwt'), isEmpty);
      expect(decodeJwtPayload('a.b'), isEmpty);
    });

    test('payload no-base64 devuelve mapa vacío', () {
      expect(decodeJwtPayload('a.@@@invalid@@@.c'), isEmpty);
    });
  });
}
