import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../utils/jwt.dart';
import 'supabase_service.dart';

/// Resultado de elegir una foto (bytes + nombre para detectar mime).
class PickedProductPhoto {
  const PickedProductPhoto({required this.bytes, this.fileName});

  final Uint8List bytes;
  final String? fileName;
}

/// Fotos en Storage: `feria-fotos/{tenant_id}/{tipo}/{producto_id}/{timestamp}.ext`
/// Ej: `0853ba51-.../arma_corta/ac-001/1734567890123.jpg` (AR-12).
class ProductPhotoService {
  final _picker = ImagePicker();

  static String folderFor(Product product) => product.type.key;

  static String newStoragePath(
    Product product, {
    String? tenantId,
    String? fileName,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = _extensionFor(fileName, fallback: 'jpg');
    final leaf = '${product.type.key}/${product.id}/$ts.$ext';
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

  Future<PickedProductPhoto?> pickPhoto({ImageSource? source}) async {
    if (kIsWeb) {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return null;

      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError(
          'No se pudieron leer los bytes de la imagen en el navegador. '
          'Probá con JPG/PNG más chico (máx. 5 MB).',
        );
      }
      return PickedProductPhoto(bytes: bytes, fileName: file.name);
    }

    final photo = await _picker.pickImage(
      source: source ?? ImageSource.gallery,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (photo == null) return null;
    final bytes = await photo.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('La imagen quedó vacía.');
    }
    return PickedProductPhoto(bytes: bytes, fileName: photo.name);
  }

  /// Compat: solo bytes (mobile antiguo). Preferí [pickPhoto].
  Future<Uint8List?> pickPhotoBytes({ImageSource? source}) async {
    final picked = await pickPhoto(source: source);
    return picked?.bytes;
  }

  Future<String> uploadBytes(
    Product product,
    Uint8List bytes, {
    String? fileName,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    final path = newStoragePath(product, fileName: fileName);
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw StateError('La foto supera el máximo de 5 MB.');
    }

    final contentType = _contentTypeFor(fileName, bytes);

    await SupabaseService.client.storage
        .from(AppConfig.productPhotosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
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

  static String _extensionFor(String? fileName, {required String fallback}) {
    final name = (fileName ?? '').trim().toLowerCase();
    if (name.endsWith('.png')) return 'png';
    if (name.endsWith('.webp')) return 'webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'jpg';
    return fallback;
  }

  static String _contentTypeFor(String? fileName, Uint8List bytes) {
    final ext = _extensionFor(fileName, fallback: '');
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
        return 'image/jpeg';
    }

    // Magic bytes si el nombre no ayuda.
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
