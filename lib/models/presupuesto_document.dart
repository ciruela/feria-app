import 'budget.dart';
import 'presupuesto_branding.dart';
import 'presupuesto_summary.dart';

export 'presupuesto_branding.dart';

class PresupuestoItemRow {
  const PresupuestoItemRow({
    required this.lineKey,
    required this.code,
    required this.quantity,
    required this.detail,
    required this.tc,
    required this.unitPrice,
    required this.lineTotal,
    required this.isArma,
    this.serialNumber = '',
    this.showsTarjetaConsumo = true,
  });

  const PresupuestoItemRow.empty()
      : lineKey = '',
        code = '',
        quantity = 0,
        detail = '',
        tc = '',
        unitPrice = '',
        lineTotal = '',
        isArma = false,
        serialNumber = '',
        showsTarjetaConsumo = true;

  factory PresupuestoItemRow.fromLine(BudgetLine line) {
    return PresupuestoItemRow(
      lineKey: line.lineKey,
      code: line.code,
      quantity: line.quantity,
      detail: line.detail,
      tc: line.tarjetaConsumo.trim(),
      unitPrice: line.formattedUnitPlain,
      lineTotal: line.formattedLinePlain,
      isArma: line.isArma,
      serialNumber: line.serialNumber,
      // Accesorios no llevan tarjeta de consumo.
      showsTarjetaConsumo: line.showsTarjetaConsumo,
    );
  }

  final String lineKey;
  final String code;
  final int quantity;
  final String detail;
  final String tc;
  final String unitPrice;
  final String lineTotal;
  final bool isArma;
  final String serialNumber;

  /// Si la fila puede editar tarjeta de consumo (falso para accesorios).
  final bool showsTarjetaConsumo;

  bool get isEmpty => code.isEmpty && detail.isEmpty;

  String get detailWithSerial {
    if (isArma && serialNumber.trim().isNotEmpty) {
      return '$detail\nSERIE: ${serialNumber.trim()}';
    }
    return detail;
  }
}

class PaymentCheckItem {
  const PaymentCheckItem({
    required this.label,
    required this.checked,
  });

  final String label;
  final bool checked;
}

/// Vista unificada del comprobante para UI y PDF.
class PresupuestoDocument {
  PresupuestoDocument._({
    required this.day,
    required this.month,
    required this.year,
    required this.customer,
    required this.summary,
    required this.tableRows,
    required this.branding,
    required this.formattedDate,
    this.sellerName,
  });

  factory PresupuestoDocument.fromBudget(
    Budget budget, {
    required PresupuestoBranding branding,
  }) {
    final date = budget.date;
    final rows = budget.lines.map(PresupuestoItemRow.fromLine).toList();
    while (rows.length < branding.paperRows) {
      rows.add(const PresupuestoItemRow.empty());
    }

    return PresupuestoDocument._(
      day: date.day.toString().padLeft(2, '0'),
      month: date.month.toString().padLeft(2, '0'),
      year: date.year.toString(),
      customer: budget.customer,
      summary: PresupuestoSummary(budget),
      tableRows: rows,
      sellerName: budget.sellerName,
      branding: branding,
      formattedDate: _formatDocumentDate(date, branding),
    );
  }

  static String _formatDocumentDate(DateTime date, PresupuestoBranding branding) {
    if (branding.useSingleDateLine) {
      const months = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  final String day;
  final String month;
  final String year;
  final BudgetCustomer customer;
  final PresupuestoSummary summary;
  final List<PresupuestoItemRow> tableRows;
  final PresupuestoBranding branding;
  final String formattedDate;
  final String? sellerName;
}
