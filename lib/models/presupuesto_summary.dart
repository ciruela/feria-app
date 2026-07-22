import 'budget.dart';
import 'cart_checkout_payment.dart';
import 'presupuesto_document.dart';
import 'product_prices.dart';
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
