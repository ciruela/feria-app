import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/budget.dart';
import '../models/presupuesto_branding.dart';
import '../models/sale_record.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import '../utils/presupuesto_pdf.dart';
import '../utils/retry.dart';
import '../utils/share_pdf.dart';
import 'supabase_service.dart';

class ComprobantePdfService {
  Future<String> uploadForSale(
    String saleId,
    Budget budget, {
    String? tenantId,
    required PresupuestoBranding branding,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    final bytes = await PresupuestoPdf.generate(budget, branding: branding);
    final path = storagePath(
      saleId: saleId,
      date: budget.date,
      tenantId: tenantId,
    );

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

  static String storagePath({
    required String saleId,
    required DateTime date,
    String? tenantId,
  }) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final tenantPrefix = tenantId?.trim();
    if (tenantPrefix == null || tenantPrefix.isEmpty) {
      throw StateError(
        'Falta tenant_id para guardar el comprobante en Storage.',
      );
    }
    return '$tenantPrefix/$year/$month/$saleId.pdf';
  }

  Future<Uint8List> fetchPdfBytes(String pdfPath) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    try {
      final data = await SupabaseService.client.storage
          .from(AppConfig.comprobantesBucket)
          .download(pdfPath);
      return Uint8List.fromList(data);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'Download autenticado falló para $pdfPath, probando URL firmada',
        error: error,
        stackTrace: stackTrace,
      );
      return _fetchPdfBytesSigned(pdfPath);
    }
  }

  Future<Uint8List> bytesForSale(
    SaleRecord sale, {
    required PresupuestoBranding branding,
  }) async {
    if (sale.hasPdf) {
      return fetchPdfBytes(sale.pdfPath!);
    }
    return PresupuestoPdf.generate(sale.toBudget(), branding: branding);
  }

  Future<void> viewSalePdf(
    SaleRecord sale, {
    required PresupuestoBranding branding,
  }) async {
    final bytes = await bytesForSale(sale, branding: branding);
    final name = sale.hasPdf
        ? sale.pdfPath!.split('/').last
        : PresupuestoPdf.fileName(sale.toBudget(), branding: branding);
    await Printing.layoutPdf(
      name: name,
      onLayout: (_) async => bytes,
    );
  }

  Future<void> shareSalePdf(
    SaleRecord sale, {
    required PresupuestoBranding branding,
  }) async {
    final bytes = await bytesForSale(sale, branding: branding);
    final name = sale.hasPdf
        ? sale.pdfPath!.split('/').last
        : PresupuestoPdf.fileName(sale.toBudget(), branding: branding);
    await sharePdfBytes(bytes: bytes, filename: name);
  }

  /// Sube el PDF si falta y actualiza `ventas.pdf_path`.
  Future<String> ensureStoredForSale(
    SaleRecord sale, {
    String? tenantId,
    required PresupuestoBranding branding,
  }) async {
    if (sale.hasPdf) return sale.pdfPath!;

    final session = SupabaseService.client.auth.currentSession;
    final resolvedTenant = tenantId ??
        (session == null
            ? null
            : (decodeJwtPayload(session.accessToken)['tenant_id'] as String?));

    final budget = sale.toBudget();
    final path = await uploadForSale(
      sale.id,
      budget,
      tenantId: resolvedTenant,
      branding: branding,
    );

    await SupabaseService.client.rpc(
      'set_venta_pdf_path',
      params: {
        'p_venta_id': sale.id,
        'p_path': path,
      },
    );

    return path;
  }

  static Future<void> viewStoredPdf(String pdfPath) async {
    final bytes = await ComprobantePdfService().fetchPdfBytes(pdfPath);
    await Printing.layoutPdf(
      name: pdfPath.split('/').last,
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareStoredPdf(String pdfPath) async {
    final bytes = await ComprobantePdfService().fetchPdfBytes(pdfPath);
    await sharePdfBytes(
      bytes: Uint8List.fromList(bytes),
      filename: pdfPath.split('/').last,
    );
  }

  static Future<Uint8List> _fetchPdfBytesSigned(String pdfPath) async {
    final url = await SupabaseService.signedComprobanteUrl(pdfPath);
    if (url == null) {
      throw StateError('No se pudo resolver la URL del comprobante');
    }

    final response = await withTimeoutRetry(
      () => http.get(Uri.parse(url)),
      timeout: const Duration(seconds: 30),
      maxAttempts: 3,
      operation: 'download comprobante pdf',
    );
    if (response.statusCode != 200) {
      throw StateError('No se pudo descargar el PDF (${response.statusCode})');
    }

    return Uint8List.fromList(response.bodyBytes);
  }
}
