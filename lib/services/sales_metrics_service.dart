import '../models/sale_record.dart';
import '../models/sales_metrics.dart';
import 'catalog_service.dart';
import 'supabase_sales_repository.dart';

class SalesMetricsService {
  SalesMetricsService({CatalogService? catalog})
      : _repository = SupabaseSalesRepository(catalog: catalog);

  final SupabaseSalesRepository _repository;

  Future<DaySalesMetrics> metricsForDay(DateTime day) async {
    final sales = await _repository.fetchForDay(day);
    return DaySalesMetrics.fromSales(day, sales);
  }

  Future<DaySalesMetrics> metricsForRange(DateTime start, DateTime end) async {
    final sales = await _repository.fetchForRange(start, end);
    return DaySalesMetrics.fromSales(start, sales);
  }

  Future<List<SaleRecord>> salesForRange(DateTime start, DateTime end) {
    return _repository.fetchForRange(start, end);
  }

  /// Búsqueda auditada por DNI (RPC; no filtro PostgREST).
  Future<List<SaleRecord>> salesByDni(String dni) {
    return _repository.searchByDni(dni);
  }

  Future<bool> voidSale(
    SaleRecord sale, {
    required String motivo,
    String? actorId,
    String? actorNombre,
  }) {
    return _repository.voidSale(
      sale,
      motivo: motivo,
      actorId: actorId,
      actorNombre: actorNombre,
    );
  }

  Future<bool> setFacturada(
    SaleRecord sale, {
    required bool facturada,
    String? facturaNumero,
    String? actorNombre,
  }) {
    return _repository.setFacturada(
      sale,
      facturada: facturada,
      facturaNumero: facturaNumero,
      actorNombre: actorNombre,
    );
  }

  Future<int> setFacturadaBatch(
    Iterable<SaleRecord> sales, {
    required bool facturada,
    String? actorNombre,
  }) {
    return _repository.setFacturadaBatch(
      sales,
      facturada: facturada,
      actorNombre: actorNombre,
    );
  }
}
