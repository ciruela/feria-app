import '../config/app_config.dart';
import '../models/budget.dart';
import '../models/customer_record.dart';
import '../utils/app_logger.dart';
import 'supabase_service.dart';

/// Orden del listado de clientes (mapea a `p_sort` en la RPC list_clientes).
enum ClientesSort {
  recent('recent', 'Recientes'),
  name('name', 'Apellido (A–Z)'),
  sales('sales', 'Más compras');

  const ClientesSort(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

class CustomerRepository {
  /// Busca un cliente por DNI/CUIT en el tenant activo.
  /// Devuelve null si no existe o el DNI es demasiado corto.
  Future<CustomerRecord?> lookupByDni(String dni) async {
    final trimmed = dni.trim();
    if (trimmed.isEmpty) return null;

    try {
      final raw = await SupabaseService.client.rpc(
        'lookup_cliente_by_dni',
        params: {'p_dni': trimmed},
      );
      return _recordFromRpc(raw);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'lookup_cliente_by_dni falló',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<CustomerRecord>> list({
    String query = '',
    int limit = 1000,
    ClientesSort sort = ClientesSort.recent,
    bool onlyWithSales = false,
    String fiscalCondition = '',
    DateTime? lastSaleFrom,
    DateTime? lastSaleTo,
  }) async {
    if (!AppConfig.useSupabase) return const [];

    try {
      final raw = await SupabaseService.client.rpc(
        'list_clientes',
        params: {
          'p_query': query.trim(),
          'p_limit': limit,
          'p_sort': sort.wireValue,
          'p_only_with_sales': onlyWithSales,
          'p_fiscal': fiscalCondition.trim(),
          'p_from': lastSaleFrom?.toUtc().toIso8601String(),
          'p_to': lastSaleTo?.toUtc().toIso8601String(),
        },
      );
      if (raw is! List) return const [];
      return raw
          .map((row) => _recordFromRpc(row))
          .whereType<CustomerRecord>()
          .toList();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'list_clientes falló',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Condiciones fiscales presentes en la base del tenant (para el filtro).
  Future<List<String>> fiscalConditions() async {
    if (!AppConfig.useSupabase) return const [];

    try {
      final raw = await SupabaseService.client.rpc(
        'list_cliente_fiscal_conditions',
      );
      if (raw is! List) return const [];
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (error, stackTrace) {
      AppLogger.warn(
        'list_cliente_fiscal_conditions falló',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  Future<CustomerRecord?> getById(String id) async {
    if (!AppConfig.useSupabase || id.trim().isEmpty) return null;

    try {
      final raw = await SupabaseService.client.rpc(
        'get_cliente_by_id',
        params: {'p_id': id.trim()},
      );
      return _recordFromRpc(raw);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'get_cliente_by_id falló',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> update(String id, BudgetCustomer customer) async {
    try {
      final raw = await SupabaseService.client.rpc(
        'update_cliente',
        params: {
          'p_id': id.trim(),
          'p_customer': customer.toJson(),
        },
      );
      return raw == true;
    } catch (error, stackTrace) {
      AppLogger.warn(
        'update_cliente falló',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  CustomerRecord? _recordFromRpc(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    if (map['id'] == null) return null;
    return CustomerRecord.fromRpc(map);
  }
}

/// Normaliza DNI/CUIT igual que `normalize_dni` en Postgres (solo dígitos).
String normalizeDni(String value) =>
    value.replaceAll(RegExp(r'[^0-9]'), '');
