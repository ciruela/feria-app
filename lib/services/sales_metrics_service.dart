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
}
