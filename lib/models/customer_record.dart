import 'budget.dart';

/// Perfil persistente de cliente (tabla `clientes` en Supabase).
class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.customer,
    required this.saleCount,
    this.lastSaleAt,
  });

  final String id;
  final BudgetCustomer customer;
  final int saleCount;
  final DateTime? lastSaleAt;

  factory CustomerRecord.fromRpc(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString() ?? '';
    final lastRaw = json['lastSaleAt'];
    DateTime? lastSaleAt;
    if (lastRaw is String && lastRaw.isNotEmpty) {
      lastSaleAt = DateTime.tryParse(lastRaw);
    }

    return CustomerRecord(
      id: read('id'),
      customer: BudgetCustomer(
        fullName: read('fullName'),
        dni: read('dni'),
        clu: read('clu'),
        cluExpiry: read('cluExpiry'),
        phone: read('phone'),
        email: read('email'),
        fiscalCondition: read('fiscalCondition'),
        address: read('address'),
        city: read('city'),
        notes: read('notes'),
      ),
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      lastSaleAt: lastSaleAt,
    );
  }
}
