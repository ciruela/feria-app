import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../utils/jwt.dart';
import 'supabase_service.dart';

/// Fotos en Storage: `feria-fotos/{tenant_id}/{tipo}/{producto_id}/{timestamp}.jpg`
/// Ej: `0853ba51-.../arma_corta/ac-001/1734567890123.jpg` (AR-12).
class ProductPhotoService {
  final _picker = ImagePicker();

  static String folderFor(Product product) => product.type.key;

  static String newStoragePath(Product product, {String? tenantId}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final leaf = '${product.type.key}/${product.id}/$ts.jpg';
    final tenant = (tenantId ?? _tenantIdFromJwt())?.trim();
    if (tenant == null || tenant.isEmpty) {
      throw StateError('Sesión sin tenant: no se puede subir la foto.');
    }
    return '$tenant/$leaf';
  }

  static String? _tenantIdFromJwt() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
    final id = (claim is String ? claim : claim?.toString())?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  static String stripVersion(String path) {
    return path.split('?').first;
  }

  static String normalizeForStorage(String fotoUrl) {
    if (fotoUrl.isEmpty) return '';

    var value = stripVersion(fotoUrl.trim());

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return value;
    }

    final marker = '/object/public/${AppConfig.productPhotosBucket}/';
    final idx = value.indexOf(marker);
    if (idx < 0) return value;

    return value.substring(idx + marker.length);
  }

  static String? displayUrl(String storagePath) {
    if (storagePath.isEmpty) return null;

    var path = storagePath;
    String? query;
    if (storagePath.contains('?')) {
      final parts = storagePath.split('?');
      path = parts.first;
      query = parts.sublist(1).join('?');
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return storagePath;
    }

    final base = SupabaseService.publicPhotoUrl(path);
    if (base == null) return null;
    return query == null ? base : '$base?$query';
  }

  static List<String> displayUrls(List<String> storagePaths) {
    return storagePaths
        .map(displayUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();
  }

  static List<String> parsePathsFromRow(Map<String, dynamic> row) {
    final paths = <String>[];

    final fotos = row['fotos'];
    if (fotos is List) {
      for (final item in fotos) {
        if (item is String && item.trim().isNotEmpty) {
          final normalized = normalizeForStorage(item);
          if (!paths.contains(normalized)) {
            paths.add(normalized);
          }
        }
      }
    }

    final legacy = row['foto_url'] as String? ?? '';
    if (legacy.trim().isNotEmpty) {
      final normalized = normalizeForStorage(legacy);
      if (!paths.contains(normalized)) {
        paths.insert(0, normalized);
      }
    }

    return paths;
  }

  static List<String> pathsForStorage(Product product) {
    return product.fotoUrls
        .map(normalizeForStorage)
        .map(stripVersion)
        .where((path) => path.isNotEmpty)
        .toList();
  }

  Future<Uint8List?> pickPhotoBytes({ImageSource? source}) async {
    if (kIsWeb) {
      final picked = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return null;
      return picked.files.single.bytes;
    }

    final photo = await _picker.pickImage(
      source: source ?? ImageSource.gallery,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (photo == null) return null;
    return photo.readAsBytes();
  }

  Future<String> uploadBytes(Product product, Uint8List bytes) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    final path = newStoragePath(product);
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw StateError('La foto supera el máximo de 5 MB.');
    }

    await SupabaseService.client.storage
        .from(AppConfig.productPhotosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return path;
  }

  Future<void> delete(String storagePath) async {
    if (!SupabaseService.isConfigured) return;

    final path = stripVersion(normalizeForStorage(storagePath));
    if (path.isEmpty) return;

    await SupabaseService.client.storage
        .from(AppConfig.productPhotosBucket)
        .remove([path]);
  }
}
