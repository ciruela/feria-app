import 'package:flutter/foundation.dart';

import '../models/audit_entry.dart';
import '../models/budget.dart';
import '../models/sale_record.dart';
import '../models/presupuesto_branding.dart';
import '../utils/app_logger.dart';
import '../utils/jwt.dart';
import '../utils/retry.dart';
import 'audit_service.dart';
import 'catalog_service.dart';
import 'pricing_settings_service.dart';
import 'supabase_service.dart';
import 'comprobante_pdf_service.dart';

/// AR-31: server vs client totals. Both currencies are required — dollar-cash
/// sales have total_ars = 0 on both sides, so only USD catches a drift.
@visibleForTesting
bool saleTotalsDiverge({
  required double serverArs,
  required double serverUsd,
  required double clientArs,
  required double clientUsd,
}) {
  final arsGap = (serverArs - clientArs).abs();
  final usdGap = (serverUsd - clientUsd).abs();
  return arsGap > 1.0 || usdGap > 0.01;
}

class SupabaseSalesRepository {
  SupabaseSalesRepository({CatalogService? catalog}) : _catalog = catalog;

  final CatalogService? _catalog;
  final ComprobantePdfService _pdfService = ComprobantePdfService();

  Future<List<SaleRecord>> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return fetchForRange(start, end);
  }

  Future<List<SaleRecord>> fetchForRange(DateTime start, DateTime end) async {
    // AR-14: sin SELECT PostgREST sobre ventas (PII); listado vía RPC gestor.
    final rows = await SupabaseService.client.rpc(
      'list_ventas_for_range',
      params: {
        'p_from': start.toUtc().toIso8601String(),
        'p_to': end.toUtc().toIso8601String(),
      },
    );

    return (rows as List<dynamic>)
        .map((row) => SaleRecord.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  /// Búsqueda por DNI con auditoría server-side (body RPC, no query string).
  Future<List<SaleRecord>> searchByDni(String dni) async {
    final rows = await SupabaseService.client.rpc(
      'search_ventas_by_dni',
      params: {'p_dni': dni.trim()},
    );

    return (rows as List<dynamic>)
        .map((row) => SaleRecord.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> insert(
    Budget budget, {
    required String idempotencyKey,
    String? sellerId,
    PricingSettingsService? pricingSettings,
    required PresupuestoBranding branding,
  }) async {
    final quantities = _quantitiesFromBudgetLines(budget.lines);
    if (_catalog != null) {
      final error = _catalog.validateSaleQuantities(quantities);
      if (error != null) throw StateError(error);
    }

    final paymentMethods =
        budget.paymentMethods.map((method) => method.key).join(', ');

    final items = _itemsPayload(budget);
    // Clave del carrito (checkout attempt): reintentos del usuario reutilizan la misma.
    final pricing = _pricingPayload(pricingSettings);
    final rpcParams = {
      'p_items': items,
      'p_metodo_pago': paymentMethods.isNotEmpty ? paymentMethods : 'lista',
      'p_cliente_nombre': budget.customer.fullName,
      'p_cliente_dni': budget.customer.dni,
      'p_vendedor_id': sellerId,
      'p_idempotency_key': idempotencyKey,
      'p_pricing': pricing,
    };

    Map<String, dynamic> result;
    try {
      result = await _registerSaleWithRetry(rpcParams);
    } catch (error, stackTrace) {
      throw _mapRegisterSaleError(error, stackTrace);
    }

    final saleId = result['id'] as String?;
    if (saleId == null || saleId.isEmpty) {
      throw StateError('La venta no devolvió id.');
    }

    // Stock server-side ya aplicado; no volver a descontar en reintento idempotente.
    final idempotent = result['idempotent'] == true;
    if (_catalog != null && !idempotent) {
      await _catalog.applyLocalSaleStockDecrement(quantities);
    }

    final serverArs = (result['total_ars'] as num?)?.toDouble() ?? 0;
    final serverUsd = (result['total_usd'] as num?)?.toDouble() ?? 0;
    if (saleTotalsDiverge(
      serverArs: serverArs,
      serverUsd: serverUsd,
      clientArs: budget.totalArsLines,
      clientUsd: budget.totalUsdLines,
    )) {
      await _rollbackSale(
        saleId: saleId,
        quantities: quantities,
        error: StateError(
          'total divergente: ARS $serverArs vs ${budget.totalArsLines}, '
          'USD $serverUsd vs ${budget.totalUsdLines}',
        ),
      );
      throw StateError(
        'El precio cambió mientras se confirmaba la venta. '
        'Se anuló el registro; volvé a generar el comprobante.',
      );
    }

    final tenantId = _currentTenantId();

    try {
      await _uploadPdfWithRetry(
        saleId: saleId,
        budget: budget,
        tenantId: tenantId,
        branding: branding,
      );
    } catch (error, stackTrace) {
      await _rollbackSale(
        saleId: saleId,
        quantities: quantities,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final itemsCount = budget.lines.fold<int>(0, (sum, l) => sum + l.quantity);
    final totalUsd = (result['total_usd'] as num?)?.toDouble() ??
        budget.totalUsdLines;
    AuditService.instance.log(
      accion: 'Registró venta',
      entidad: AuditEntidad.venta,
      entidadId: saleId,
      // AR-14: no repetir PII del comprador en audit_log.detalle.
      detalle: '$itemsCount ítems · USD ${totalUsd.toStringAsFixed(0)}',
      actorId: sellerId,
      actorNombre: budget.sellerName ?? 'Vendedor',
    );
  }

  Future<void> _rollbackSale({
    required String saleId,
    required Map<String, int> quantities,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    AppLogger.warn(
      'Anulando venta $saleId tras error en PDF',
      error: error,
      stackTrace: stackTrace,
    );

    try {
      await SupabaseService.client.rpc(
        'void_sale',
        params: {
          'p_venta_id': saleId,
          'p_motivo': 'Rollback automático: fallo al guardar PDF',
          'p_actor_nombre': 'sistema',
        },
      );
      if (_catalog != null) {
        await _catalog.applyLocalSaleStockRestore(quantities);
      }
    } catch (voidError, voidStack) {
      AppLogger.error(
        'No se pudo anular venta $saleId tras fallo de PDF',
        error: voidError,
        stackTrace: voidStack,
      );
    }
  }

  Future<bool> voidSale(
    SaleRecord sale, {
    required String motivo,
    String? actorId,
    String? actorNombre,
  }) async {
    // RPC atómica (AR-8): segunda anulación no restituye stock.
    final dynamic raw;
    try {
      raw = await SupabaseService.client.rpc(
        'void_sale',
        params: {
          'p_venta_id': sale.id,
          'p_motivo': motivo,
          'p_actor_nombre': actorNombre ?? '',
        },
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('cannot_reactivate_sale')) {
        throw StateError('No se puede reactivar una venta anulada.');
      }
      rethrow;
    }
    final ok = raw == true;
    if (!ok) return false;

    if (_catalog != null) {
      await _catalog.applyLocalSaleStockRestore(
        _quantitiesFromSaleLines(sale.lines),
      );
    }

    AuditService.instance.log(
      accion: 'Anuló venta',
      entidad: AuditEntidad.venta,
      entidadId: sale.id,
      detalle: 'Motivo: $motivo',
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
    final raw = await SupabaseService.client.rpc(
      'set_venta_facturada',
      params: {
        'p_venta_id': sale.id,
        'p_facturada': facturada,
        'p_factura_numero': facturaNumero?.trim() ?? '',
        'p_actor_nombre': actorNombre ?? '',
      },
    );
    final ok = raw == true;
    if (!ok) return false;

    AuditService.instance.log(
      accion: facturada ? 'Marcó facturada' : 'Desmarcó facturada',
      entidad: AuditEntidad.venta,
      entidadId: sale.id,
      detalle: facturada && (facturaNumero?.trim().isNotEmpty ?? false)
          ? 'Factura ${facturaNumero!.trim()}'
          : '',
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
    required PresupuestoBranding branding,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final pdfPath = await _pdfService.uploadForSale(
          saleId,
          budget,
          tenantId: tenantId,
          branding: branding,
        );
        await SupabaseService.client.rpc(
          'set_venta_pdf_path',
          params: {
            'p_venta_id': saleId,
            'p_path': pdfPath,
          },
        );
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
        'fiscalCondition': budget.customer.fiscalCondition,
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
              // Precios solo como referencia UI; el servidor los recalcula.
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
      if (budget.paymentAllocations.isNotEmpty)
        'allocations': _allocationShares(budget),
    };
  }

  List<Map<String, dynamic>> _allocationShares(Budget budget) {
    return budget.paymentAllocations
        .map(
          (allocation) => {
            'method': allocation.method.key,
            // share de la venta (suma 1), no proporción dentro de una moneda.
            'share': allocation.share,
          },
        )
        .toList();
  }

  Map<String, dynamic> _pricingPayload(PricingSettingsService? settings) {
    if (settings == null) return <String, dynamic>{};
    return {
      'efectivo': settings.descuentoEfectivoPct,
      'debito': settings.recargoDebitoPct,
      'tarjeta1': settings.recargoTarjeta1Pct,
      'tarjeta3': settings.recargoTarjeta3Pct,
      'tarjeta6': settings.recargoTarjeta6Pct,
      'tarjeta9': settings.recargoTarjeta9Pct,
      'tarjeta12': settings.recargoTarjeta12Pct,
      'tarjeta18': settings.recargoTarjeta18Pct,
    };
  }

  Future<Map<String, dynamic>> _registerSaleWithRetry(
    Map<String, dynamic> params,
  ) async {
    final raw = await withTimeoutRetry(
      () => SupabaseService.client.rpc(
        'register_sale',
        params: params,
      ),
      timeout: const Duration(seconds: 25),
      maxAttempts: 3,
      operation: 'register_sale',
    );
    return _asStringKeyedMap(raw);
  }

  Map<String, dynamic> _asStringKeyedMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    throw StateError('Respuesta inválida de register_sale.');
  }

  StateError _mapRegisterSaleError(Object error, StackTrace stackTrace) {
    AppLogger.error('register_sale falló', error: error, stackTrace: stackTrace);
    final message = error.toString();
    if (message.contains('insufficient_stock')) {
      return StateError('Stock insuficiente para completar la venta.');
    }
    if (message.contains('product_not_found')) {
      return StateError('Hay productos que ya no existen en el catálogo.');
    }
    if (message.contains('exchange_rate_missing')) {
      return StateError('Falta configurar el tipo de cambio.');
    }
    if (message.contains('tenant_required')) {
      return StateError('Sesión sin tenant activo. Volvé a ingresar.');
    }
    if (message.contains('forbidden_role')) {
      return StateError('Tu rol no permite registrar ventas.');
    }
    if (message.contains('sale_missing_stock_movements')) {
      return StateError(
        'La venta no pudo confirmarse con su descuento de stock.',
      );
    }
    return StateError('No se pudo registrar la venta. $message');
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
