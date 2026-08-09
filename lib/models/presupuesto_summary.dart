import 'budget.dart';
import 'presupuesto_document.dart';
import 'product_prices.dart';
import 'urban_receipt_options.dart';
import '../utils/formatters.dart';

/// Datos de presentación compartidos entre el comprobante en pantalla y el PDF.
class PresupuestoSummary {
  PresupuestoSummary(this.budget);

  final Budget budget;

  Set<PaymentMethod> get paymentMethods => budget.paymentMethods;

  bool get hasUsdTotal => budget.hasUsdPayments;

  bool get hasArsTotal => budget.hasArsPayments;

  String get formattedUsdTotal =>
      formatUsd(budget.totalUsdLines).replaceAll('USD ', '');

  String get formattedArsTotal =>
      formatArs(budget.totalArsLines).replaceAll(r'$ ', '');

  List<PaymentAllocationLine> get paymentAllocationLines {
    return budget.paymentAllocations
        .map(
          (allocation) => PaymentAllocationLine(
            label: allocation.method.label.toUpperCase(),
            amount: allocation.paysInUsd
                ? formatUsd(allocation.amountUsd)
                : formatArs(allocation.amountArs),
          ),
        )
        .toList();
  }

  bool get usesPesos =>
      paymentMethods.contains(PaymentMethod.lista) ||
      paymentMethods.contains(PaymentMethod.transferencia) ||
      paymentMethods.contains(PaymentMethod.efectivo) ||
      paymentMethods.contains(PaymentMethod.debito) ||
      paymentMethods.any((method) => method.name.startsWith('tarjeta'));

  List<PaymentCheckItem> get primaryPaymentChecks {
    final methods = paymentMethods;
    return [
      PaymentCheckItem(
        label: 'EFVO.',
        checked: methods.contains(PaymentMethod.efectivo),
      ),
      PaymentCheckItem(
        label: 'DEBITO',
        checked: methods.contains(PaymentMethod.debito),
      ),
      PaymentCheckItem(
        label: 'TRANSFERENCIA',
        checked: methods.contains(PaymentMethod.transferencia),
      ),
      PaymentCheckItem(label: 'PESOS', checked: usesPesos),
      PaymentCheckItem(
        label: 'U\$s',
        checked: methods.contains(PaymentMethod.dolarBillete),
      ),
    ];
  }

  /// Abreviatura para recibo Urban (EF, TR, TC, USD, OTROS, EF/TR, SORTEO).
  String get urbanPaymentAbbrev {
    final methods = paymentMethods;
    if (methods.isEmpty) return '—';

    if (methods.length == 1) {
      return _urbanAbbrevFor(methods.first);
    }

    final abbrevs = methods.map(_urbanAbbrevFor).toSet();
    if (abbrevs.length == 2 &&
        abbrevs.contains('EF') &&
        abbrevs.contains('TR')) {
      return 'EF/TR';
    }

    return abbrevs.join('/');
  }

  static String _urbanAbbrevFor(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.efectivo => 'EF',
      PaymentMethod.transferencia => 'TR',
      PaymentMethod.dolarBillete => 'USD',
      PaymentMethod.debito || PaymentMethod.lista => 'OTROS',
      PaymentMethod.tarjeta1 ||
      PaymentMethod.tarjeta3 ||
      PaymentMethod.tarjeta6 ||
      PaymentMethod.tarjeta9 ||
      PaymentMethod.tarjeta12 ||
      PaymentMethod.tarjeta18 =>
        'TC',
    };
  }

  String paymentAbbrevFor(PresupuestoBranding branding) {
    if (branding.isUrban) return urbanPaymentAbbrev;
    return paymentMethodAbbrev;
  }

  String fiscalConditionFor(PresupuestoBranding branding) {
    final raw = budget.customer.fiscalCondition.trim();
    if (raw.isNotEmpty) return raw;
    // Compat: ventas guardadas antes del campo dedicado.
    final legacy = budget.customer.email.trim();
    if (branding.isUrban &&
        UrbanReceiptOptions.fiscalConditions
            .any((option) => option.toLowerCase() == legacy.toLowerCase())) {
      return legacy;
    }
    if (branding.isUrban) return UrbanReceiptOptions.defaultFiscalCondition;
    return raw;
  }

  /// Abreviatura genérica (World Guns / estándar).
  String get paymentMethodAbbrev {
    const abbrev = {
      PaymentMethod.efectivo: 'EF',
      PaymentMethod.debito: 'DB',
      PaymentMethod.transferencia: 'TR',
      PaymentMethod.lista: 'LI',
      PaymentMethod.dolarBillete: 'US',
      PaymentMethod.tarjeta1: 'T1',
      PaymentMethod.tarjeta3: 'T3',
      PaymentMethod.tarjeta6: 'T6',
      PaymentMethod.tarjeta9: 'T9',
      PaymentMethod.tarjeta12: 'T12',
      PaymentMethod.tarjeta18: 'T18',
    };

    final parts = paymentMethods
        .map((method) => abbrev[method] ?? method.label.substring(0, 2).toUpperCase())
        .toList();
    return parts.isEmpty ? '—' : parts.join('/');
  }

  String get formattedCombinedTotal {
    final parts = <String>[];
    if (hasArsTotal) parts.add('\$ $formattedArsTotal');
    if (hasUsdTotal) parts.add('U\$S $formattedUsdTotal');
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  List<PaymentCheckItem> get creditCardChecks {
    final methods = paymentMethods;
    return [
      PaymentCheckItem(
        label: '1 CTA',
        checked: methods.contains(PaymentMethod.tarjeta1),
      ),
      PaymentCheckItem(
        label: '3 CTAS',
        checked: methods.contains(PaymentMethod.tarjeta3),
      ),
      PaymentCheckItem(
        label: '6 CTAS',
        checked: methods.contains(PaymentMethod.tarjeta6),
      ),
      PaymentCheckItem(
        label: '9 CTAS',
        checked: methods.contains(PaymentMethod.tarjeta9),
      ),
      PaymentCheckItem(
        label: '12 CTAS',
        checked: methods.contains(PaymentMethod.tarjeta12),
      ),
      PaymentCheckItem(
        label: '18 CTAS',
        checked: methods.contains(PaymentMethod.tarjeta18),
      ),
    ];
  }
}

class PaymentAllocationLine {
  const PaymentAllocationLine({
    required this.label,
    required this.amount,
  });

  final String label;
  final String amount;
}
