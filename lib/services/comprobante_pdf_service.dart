import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/budget.dart';
import '../utils/presupuesto_pdf.dart';
import 'supabase_service.dart';

class ComprobantePdfService {
  Future<String> uploadForSale(String saleId, Budget budget) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    final bytes = await PresupuestoPdf.generate(budget);
    final path = _storagePath(saleId, budget.date);

    await SupabaseService.client.storage
        .from(AppConfig.comprobantesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    return path;
  }

  static String _storagePath(String saleId, DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    return '$year/$month/$saleId.pdf';
  }

  static Future<void> viewStoredPdf(String pdfPath) async {
    final url = SupabaseService.publicComprobanteUrl(pdfPath);
    if (url == null) {
      throw StateError('No se pudo resolver la URL del comprobante');
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw StateError('No se pudo descargar el PDF (${response.statusCode})');
    }

    final bytes = Uint8List.fromList(response.bodyBytes);
    await Printing.layoutPdf(
      name: pdfPath.split('/').last,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareStoredPdf(String pdfPath) async {
    final url = SupabaseService.publicComprobanteUrl(pdfPath);
    if (url == null) {
      throw StateError('No se pudo resolver la URL del comprobante');
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw StateError('No se pudo descargar el PDF (${response.statusCode})');
    }

    await Printing.sharePdf(
      bytes: Uint8List.fromList(response.bodyBytes),
      filename: pdfPath.split('/').last,
    );
  }
}
