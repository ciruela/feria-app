import '../models/budget.dart';
import '../models/sale_record.dart';
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

    await _decrementStock(budget);
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

  Future<void> _decrementStock(Budget budget) async {
    final processed = <String>{};

    for (final line in budget.lines) {
      if (line.productId.isEmpty) continue;
      if (!processed.add(line.productId)) continue;

      await _catalog.decrementStock(line.productId, line.quantity);
    }
  }
}
