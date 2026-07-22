import '../models/sales_metrics.dart';
import 'supabase_sales_repository.dart';

class SalesMetricsService {
  final SupabaseSalesRepository _repository = SupabaseSalesRepository();

  Future<DaySalesMetrics> metricsForDay(DateTime day) async {
    final sales = await _repository.fetchForDay(day);
    return DaySalesMetrics.fromSales(day, sales);
  }
}
