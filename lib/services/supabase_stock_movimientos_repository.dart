import '../models/stock_movimiento.dart';
import 'supabase_service.dart';

class SupabaseStockMovimientosRepository {
  static const _table = 'stock_movimientos';

  Future<void> insert({
    required String productoId,
    required int delta,
    required StockMotivo motivo,
    int? stockAntes,
    int? stockDespues,
    String? ventaId,
    String? vendedorId,
    String nota = '',
  }) async {
    await SupabaseService.client.from(_table).insert({
      'producto_id': productoId,
      'delta': delta,
      'motivo': motivo.key,
      if (stockAntes != null) 'stock_antes': stockAntes,
      if (stockDespues != null) 'stock_despues': stockDespues,
      if (ventaId != null && ventaId.isNotEmpty) 'venta_id': ventaId,
      if (vendedorId != null && vendedorId.isNotEmpty) 'vendedor_id': vendedorId,
      'nota': nota,
    });
  }

  Future<List<StockMovimiento>> fetchForProduct(
    String productoId, {
    int limit = 100,
  }) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .eq('producto_id', productoId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => StockMovimiento.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<StockMovimiento>> fetchForDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return fetchForRange(start, end);
  }

  Future<List<StockMovimiento>> fetchForRange(DateTime start, DateTime end) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .gte('created_at', start.toUtc().toIso8601String())
        .lt('created_at', end.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => StockMovimiento.fromRow(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<StockMovimiento>> fetchRecent({int limit = 200}) async {
    final rows = await SupabaseService.client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => StockMovimiento.fromRow(row as Map<String, dynamic>))
        .toList();
  }
}
