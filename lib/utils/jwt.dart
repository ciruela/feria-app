import 'dart:convert';

import 'app_logger.dart';

/// Decodifica el payload de un JWT (sin validar la firma; solo para leer claims
/// del lado del cliente). La validacion real la hace Supabase/RLS en el servidor.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return const {};
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    return const {};
  } catch (e, s) {
    AppLogger.warn('No se pudo decodificar el JWT', error: e, stackTrace: s);
    return const {};
  }
}
