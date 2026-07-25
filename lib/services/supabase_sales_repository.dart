import '../models/audit_entry.dart';
import '../models/budget.dart';
import '../models/sale_record.dart';
import 'audit_service.dart';
import 'supabase_catalog_repository.dart';
import 'supabase_service.dart';
import 'comprobante_pdf_service.dart';

class SupabaseSalesRepository {
  static const _table = 'ventas';

  final SupabaseCatalogRepository _catalog = SupabaseCatalogRepository();
  final ComprobantePdfService _pdfService = ComprobantePdfService();

  Future<List<SaleRecord>> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

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

    try {
      final pdfPath = await _pdfService.uploadForSale(saleId, budget);
      await SupabaseService.client
          .from(_table)
          .update({'pdf_path': pdfPath})
          .eq('id', saleId);
    } catch (_) {
      // La venta queda guardada aunque falle el PDF.
    }

    await _decrementStock(budget, saleId: saleId, sellerId: sellerId);

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

  /// Anula una venta (soft-delete): conserva la fila para auditoría, restituye
  /// el stock de cada producto y registra la acción. Devuelve `true` si la
  /// anulación se aplicó (o `false` si la venta ya estaba anulada).
  Future<bool> voidSale(
    SaleRecord sale, {
    required String motivo,
    String? actorId,
    String? actorNombre,
  }) async {
    // Evita doble anulación (y doble restitución de stock).
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

    final quantities = <String, int>{};
    for (final line in sale.lines) {
      if (line.productId.isEmpty) continue;
      quantities.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    for (final entry in quantities.entries) {
      await _catalog.restoreStock(
        entry.key,
        entry.value,
        ventaId: sale.id,
        vendedorId: sale.vendedorId,
      );
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
              if (line.splitPart != null) 'splitPart': line.splitPart,
            },
          )
          .toList(),
      'sellerName': budget.sellerName,
      'date': budget.date.toUtc().toIso8601String(),
    };
  }

  Future<void> _decrementStock(
    Budget budget, {
    String? saleId,
    String? sellerId,
  }) async {
    final quantities = <String, int>{};

    for (final line in budget.lines) {
      if (line.productId.isEmpty) continue;
      quantities.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    for (final entry in quantities.entries) {
      await _catalog.decrementStock(
        entry.key,
        entry.value,
        ventaId: saleId,
        vendedorId: sellerId,
      );
    }
  }
}
