import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Comparte un PDF generado.
///
/// AR-60: en iOS con UIScene, [Printing.sharePdf] usa `keyWindow` (a menudo
/// nil) y el sheet no aparece. En móvil usamos [share_plus]; en web se
/// mantiene el download de `printing`.
Future<void> sharePdfBytes({
  required Uint8List bytes,
  required String filename,
}) async {
  final safeName =
      filename.trim().isEmpty ? 'comprobante.pdf' : filename.trim();

  if (kIsWeb) {
    await Printing.sharePdf(bytes: bytes, filename: safeName);
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: safeName,
        ),
      ],
    ),
  );

  if (result.status == ShareResultStatus.unavailable) {
    throw StateError(
      'No se pudo abrir el menú para compartir. Probá de nuevo o instalá '
      'una app que acepte PDF (Drive, WhatsApp, Mail).',
    );
  }
}
