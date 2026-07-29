import '../models/audit_entry.dart';
import '../models/budget.dart';
import '../models/sale_record.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import 'audit_service.dart';
import 'catalog_service.dart';
import 'supabase_catalog_repository.dart';
import 'supabase_service.dart';
import 'comprobante_pdf_service.dart';

class SupabaseSalesRepository {
  SupabaseSalesRepository({CatalogService? catalog}) : _catalog = catalog;

  static const _table = 'ventas';

  final CatalogService? _catalog;
  final SupabaseCatalogRepository _catalogRepo = SupabaseCatalogRepository();
  final ComprobantePdfService _pdfService = ComprobantePdfService();

  Future<List<SaleRecord>> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return fetchForRange(start, end);
  }

  Future<List<SaleRecord>> fetchForRange(DateTime start, DateTime end) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at');

    return (rows as List<dynamic>)
        .map((row) => SaleRecord.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> insert(
    Budget budget, {
    String? sellerId,
    double? exchangeRate,
  }) async {
    final paymentMethods =
        budget.paymentMethods.map((method) => method.key).join(', ');

    final items = _itemsPayload(budget);

    final row = await SupabaseService.client
        .from(_table)
        .insert({
          if (sellerId != null && sellerId.isNotEmpty) 'vendedor_id': sellerId,
          'items': items,
          'metodo_pago':
              paymentMethods.isNotEmpty ? paymentMethods : 'lista',
          'total_usd': budget.totalUsdLines,
          'total_ars': budget.totalArsLines,
          'tipo_cambio': exchangeRate,
          'cliente_nombre': budget.customer.fullName,
          'cliente_dni': budget.customer.dni,
        })
        .select('id')
        .single();

    final saleId = row['id'] as String;
    final tenantId = _currentTenantId();

    await _uploadPdfWithRetry(
      saleId: saleId,
      budget: budget,
      tenantId: tenantId,
    );

    await _applyStockDecrement(
      budget,
      saleId: saleId,
      sellerId: sellerId,
    );

    final itemsCount = budget.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    AuditService.instance.log(
      accion: 'Registró venta',
      entidad: AuditEntidad.venta,
      entidadId: saleId,
      detalle: '$itemsCount ítems · USD ${budget.totalUsdLines.toStringAsFixed(0)}'
          ' · ${budget.customer.fullName.isEmpty ? 'sin cliente' : budget.customer.fullName}',
      actorId: sellerId,
      actorNombre: budget.sellerName ?? 'Vendedor',
    );
  }

  Future<bool> voidSale(
    SaleRecord sale, {
    required String motivo,
    String? actorId,
    String? actorNombre,
  }) async {
    final existing = await SupabaseService.client
        .from(_table)
        .select('anulada')
        .eq('id', sale.id)
        .maybeSingle();
    if (existing == null) return false;
    if (existing['anulada'] as bool? ?? false) return false;

    await SupabaseService.client.from(_table).update({
      'anulada': true,
      'anulada_motivo': motivo,
      'anulada_por': actorNombre ?? '',
      'anulada_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sale.id);

    final quantities = _quantitiesFromSaleLines(sale.lines);

    if (_catalog != null) {
      await _catalog.applySaleStockRestore(
        quantities,
        saleId: sale.id,
        sellerId: sale.vendedorId,
      );
    } else {
      for (final entry in quantities.entries) {
        await _catalogRepo.restoreStock(
          entry.key,
          entry.value,
          ventaId: sale.id,
          vendedorId: sale.vendedorId,
        );
      }
    }

    AuditService.instance.log(
      accion: 'Anuló venta',
      entidad: AuditEntidad.venta,
      entidadId: sale.id,
      detalle:
          'Motivo: $motivo · ${sale.clienteNombre.trim().isEmpty ? 'sin cliente' : sale.clienteNombre.trim()}',
      actorId: actorId,
      actorNombre: actorNombre,
    );

    return true;
  }

  Future<bool> setFacturada(
    SaleRecord sale, {
    required bool facturada,
    String? facturaNumero,
    String? actorNombre,
  }) async {
    final existing = await SupabaseService.client
        .from(_table)
        .select('anulada, facturada')
        .eq('id', sale.id)
        .maybeSingle();
    if (existing == null) return false;
    if (existing['anulada'] as bool? ?? false) return false;

    final now = DateTime.now().toUtc().toIso8601String();
    if (facturada) {
      await SupabaseService.client.from(_table).update({
        'facturada': true,
        'facturada_at': now,
        'facturada_por': actorNombre ?? '',
        'factura_numero': facturaNumero?.trim() ?? '',
      }).eq('id', sale.id);
    } else {
      await SupabaseService.client.from(_table).update({
        'facturada': false,
        'facturada_at': null,
        'facturada_por': '',
        'factura_numero': '',
      }).eq('id', sale.id);
    }

    AuditService.instance.log(
      accion: facturada ? 'Marcó facturada' : 'Desmarcó facturada',
      entidad: AuditEntidad.venta,
      entidadId: sale.id,
      detalle: facturada && (facturaNumero?.trim().isNotEmpty ?? false)
          ? 'Factura ${facturaNumero!.trim()} · ${sale.clienteNombre.trim().isEmpty ? 'sin cliente' : sale.clienteNombre.trim()}'
          : sale.clienteNombre.trim().isEmpty
              ? 'sin cliente'
              : sale.clienteNombre.trim(),
      actorNombre: actorNombre,
    );

    return true;
  }

  Future<int> setFacturadaBatch(
    Iterable<SaleRecord> sales, {
    required bool facturada,
    String? actorNombre,
  }) async {
    var updated = 0;
    for (final sale in sales) {
      if (sale.anulada) continue;
      if (facturada && sale.facturada) continue;
      if (!facturada && !sale.facturada) continue;
      final ok = await setFacturada(
        sale,
        facturada: facturada,
        actorNombre: actorNombre,
      );
      if (ok) updated++;
    }
    return updated;
  }

  Future<void> _uploadPdfWithRetry({
    required String saleId,
    required Budget budget,
    String? tenantId,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final pdfPath = await _pdfService.uploadForSale(
          saleId,
          budget,
          tenantId: tenantId,
        );
        await SupabaseService.client
            .from(_table)
            .update({'pdf_path': pdfPath})
            .eq('id', saleId);
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        AppLogger.warn(
          'Intento $attempt: no se pudo subir PDF de venta $saleId',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      await SupabaseService.client.from(_table).delete().eq('id', saleId);
    } catch (deleteError, deleteStack) {
      AppLogger.error(
        'No se pudo revertir venta $saleId tras fallo de PDF',
        error: deleteError,
        stackTrace: deleteStack,
      );
    }

    AppLogger.error(
      'PDF no guardado para venta $saleId',
      error: lastError,
      stackTrace: lastStack,
    );
    final detail = lastError?.toString().trim();
    throw StateError(
      'No se pudo guardar el PDF del comprobante en la nube. '
      '${detail != null && detail.isNotEmpty ? 'Detalle: $detail. ' : ''}'
      'La venta no se confirmó.',
    );
  }

  String? _currentTenantId() {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;
    final claim = decodeJwtPayload(session.accessToken)['tenant_id'];
    final tenantId = (claim is String ? claim : claim?.toString())?.trim();
    return tenantId == null || tenantId.isEmpty ? null : tenantId;
  }

  Map<String, dynamic> _itemsPayload(Budget budget) {
    return {
      'customer': {
        'fullName': budget.customer.fullName,
        'dni': budget.customer.dni,
        'clu': budget.customer.clu,
        'cluExpiry': budget.customer.cluExpiry,
        'phone': budget.customer.phone,
        'email': budget.customer.email,
        'address': budget.customer.address,
        'city': budget.customer.city,
        'notes': budget.customer.notes,
      },
      'lines': budget.lines
          .map(
            (line) => {
              'productId': line.productId,
              'productType': line.productType,
              'code': line.code,
              'quantity': line.quantity,
              'detail': line.detail,
              'unitArs': line.unitArs,
              'lineArs': line.lineArs,
              'unitUsd': line.unitUsd,
              'lineUsd': line.lineUsd,
              'paymentMethod': line.paymentMethod.key,
              'isArma': line.isArma,
              'serialNumber': line.serialNumber,
              'tarjetaConsumo': line.tarjetaConsumo,
              if (line.splitPart != null) 'splitPart': line.splitPart,
            },
          )
          .toList(),
      'sellerName': budget.sellerName,
      'date': budget.date.toUtc().toIso8601String(),
    };
  }

  Future<void> _applyStockDecrement(
    Budget budget, {
    String? saleId,
    String? sellerId,
  }) async {
    final quantities = _quantitiesFromBudgetLines(budget.lines);
    if (quantities.isEmpty) return;

    if (_catalog != null) {
      await _catalog.applySaleStockDecrement(
        quantities,
        saleId: saleId,
        sellerId: sellerId,
      );
      return;
    }

    for (final entry in quantities.entries) {
      await _catalogRepo.decrementStock(
        entry.key,
        entry.value,
        ventaId: saleId,
        vendedorId: sellerId,
      );
    }
  }

  Map<String, int> _quantitiesFromBudgetLines(List<BudgetLine> lines) {
    final quantities = <String, int>{};
    for (final line in lines) {
      if (line.productId.isEmpty) continue;
      quantities.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return quantities;
  }

  Map<String, int> _quantitiesFromSaleLines(List<SaleLineRecord> lines) {
    final quantities = <String, int>{};
    for (final line in lines) {
      if (line.productId.isEmpty) continue;
      quantities.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return quantities;
  }
}
