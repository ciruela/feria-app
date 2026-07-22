import 'sale_record.dart';

class CategoryMetrics {
  const CategoryMetrics({
    this.units = 0,
    this.ars = 0,
    this.usd = 0,
  });

  final int units;
  final double ars;
  final double usd;

  CategoryMetrics merge(CategoryMetrics other) {
    return CategoryMetrics(
      units: units + other.units,
      ars: ars + other.ars,
      usd: usd + other.usd,
    );
  }
}

class PaymentMetrics {
  const PaymentMetrics({
    required this.key,
    required this.label,
    this.transactions = 0,
    this.ars = 0,
    this.usd = 0,
  });

  final String key;
  final String label;
  final int transactions;
  final double ars;
  final double usd;
}

class SellerMetrics {
  const SellerMetrics({
    required this.name,
    this.sales = 0,
    this.ars = 0,
    this.usd = 0,
  });

  final String name;
  final int sales;
  final double ars;
  final double usd;
}

class DaySalesMetrics {
  const DaySalesMetrics({
    required this.date,
    this.saleCount = 0,
    this.totalArs = 0,
    this.totalUsd = 0,
    this.armaCorta = const CategoryMetrics(),
    this.armaLarga = const CategoryMetrics(),
    this.municion = const CategoryMetrics(),
    this.payments = const [],
    this.sellers = const [],
    this.sales = const [],
  });

  final DateTime date;
  final int saleCount;
  final double totalArs;
  final double totalUsd;
  final CategoryMetrics armaCorta;
  final CategoryMetrics armaLarga;
  final CategoryMetrics municion;
  final List<PaymentMetrics> payments;
  final List<SellerMetrics> sellers;
  final List<SaleRecord> sales;

  int get totalUnits =>
      armaCorta.units + armaLarga.units + municion.units;

  factory DaySalesMetrics.fromSales(DateTime date, List<SaleRecord> sales) {
    var totalArs = 0.0;
    var totalUsd = 0.0;
    var corta = const CategoryMetrics();
    var larga = const CategoryMetrics();
    var muni = const CategoryMetrics();
    final paymentMap = <String, PaymentMetrics>{};
    final sellerMap = <String, SellerMetrics>{};

    for (final sale in sales) {
      totalArs += sale.collectedArs;
      totalUsd += sale.collectedUsd;

      final sellerName =
          (sale.sellerName?.trim().isNotEmpty ?? false)
              ? sale.sellerName!.trim()
              : 'Sin vendedor';
      final sellerExisting = sellerMap[sellerName];
      sellerMap[sellerName] = SellerMetrics(
        name: sellerName,
        sales: (sellerExisting?.sales ?? 0) + 1,
        ars: (sellerExisting?.ars ?? 0) + sale.collectedArs,
        usd: (sellerExisting?.usd ?? 0) + sale.collectedUsd,
      );

      for (final line in sale.lines) {
        final type = line.resolvedProductType;
        final countUnits = line.isSplitSecondPart
            ? 0
            : (line.isArma && line.splitPart != null ? 1 : line.quantity);

        final category = CategoryMetrics(
          units: countUnits,
          ars: line.paysInUsd ? 0 : line.lineArs,
          usd: line.paysInUsd ? line.lineUsd : 0,
        );

        switch (type) {
          case 'arma_corta':
            corta = corta.merge(category);
          case 'arma_larga':
            larga = larga.merge(category);
          default:
            muni = muni.merge(category);
        }

        final paymentKey = line.paymentMethod;
        final paymentLabel = _paymentLabel(paymentKey);
        final existing = paymentMap[paymentKey];
        paymentMap[paymentKey] = PaymentMetrics(
          key: paymentKey,
          label: paymentLabel,
          transactions: (existing?.transactions ?? 0) + 1,
          ars: (existing?.ars ?? 0) + (line.paysInUsd ? 0 : line.lineArs),
          usd: (existing?.usd ?? 0) + (line.paysInUsd ? line.lineUsd : 0),
        );
      }
    }

    final payments = paymentMap.values.toList()
      ..sort((a, b) => (b.ars + b.usd * 1000).compareTo(a.ars + a.usd * 1000));

    final sellers = sellerMap.values.toList()
      ..sort((a, b) => b.ars.compareTo(a.ars));

    return DaySalesMetrics(
      date: date,
      saleCount: sales.length,
      totalArs: totalArs,
      totalUsd: totalUsd,
      armaCorta: corta,
      armaLarga: larga,
      municion: muni,
      payments: payments,
      sellers: sellers,
      sales: sales,
    );
  }

  static String _paymentLabel(String key) {
    return switch (key) {
      'dolar_billete' => 'Dólar billete',
      'transferencia' => 'Transferencia',
      'lista' => 'Lista',
      'efectivo' => 'Efectivo',
      'debito' => 'Débito',
      'tarjeta1' => 'Tarjeta 1 cuota',
      'tarjeta3' => 'Tarjeta 3 cuotas',
      'tarjeta6' => 'Tarjeta 6 cuotas',
      'tarjeta9' => 'Tarjeta 9 cuotas',
      'tarjeta12' => 'Tarjeta 12 cuotas',
      'tarjeta18' => 'Tarjeta 18 cuotas',
      _ => key,
    };
  }
}
