import 'budget.dart';
import 'presupuesto_summary.dart';
import 'product_prices.dart';

/// Textos y constantes compartidos entre el comprobante en pantalla y el PDF.
abstract final class PresupuestoBranding {
  static const paperRows = 14;
  static const documentTitle = 'PRESUPUESTO';
  static const documentSubtitle = '(DOC. NO VALIDO COMO FACTURA)';
  static const companyName = 'WORLD GUNS S.R.L.';
  static const businessLine = 'ARMERIA - CUCHILLERIA - ACCESORIOS';
  static const servicesLine = 'GESTORIA ANMAC P/CIVILES - FUERZAS-EMPRESAS';
  static const addressLine =
      'Triunvirato 2589 1 Piso (Villa Luzuriaga - Pcia. Bs.As.)';
  static const phoneLine = 'Tel: 4835-9420  Ventas WApp: 11-3864-4279';
  static const adminLine = 'Adm./Gestoria WApp: 11-5147-1705  @wordguns.srl';
  static const footerNote =
      'Horario: Lun a Vie 10 a 13 y 15:30 a 19 · Sab 10 a 13\n'
      'Los precios pueden variar sin previo aviso.\n'
      'Reserva de mercaderia con seña del 30%.';
  static const paymentAllocationTitle = 'FORMA DE PAGO ACORDADA';
  static const creditCardsTitle = 'TARJETAS DE CREDITO';
  static const tableHeaders = ['COD', 'CANT', 'DETALLE', 'P. UNIT', 'IMPORTE'];
}

class PresupuestoItemRow {
  const PresupuestoItemRow({
    required this.lineKey,
    required this.code,
    required this.quantity,
    required this.detail,
    required this.unitPrice,
    required this.lineTotal,
    required this.isArma,
    this.serialNumber = '',
  });

  const PresupuestoItemRow.empty()
      : lineKey = '',
        code = '',
        quantity = 0,
        detail = '',
        unitPrice = '',
        lineTotal = '',
        isArma = false,
        serialNumber = '';

  factory PresupuestoItemRow.fromLine(BudgetLine line) {
    return PresupuestoItemRow(
      lineKey: line.lineKey,
      code: line.code,
      quantity: line.quantity,
      detail: line.detail,
      unitPrice: line.formattedUnitPlain,
      lineTotal: line.formattedLinePlain,
      isArma: line.isArma,
      serialNumber: line.serialNumber,
    );
  }

  final String lineKey;
  final String code;
  final int quantity;
  final String detail;
  final String unitPrice;
  final String lineTotal;
  final bool isArma;
  final String serialNumber;

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
    this.sellerName,
  });

  factory PresupuestoDocument.fromBudget(Budget budget) {
    final date = budget.date;
    final rows = budget.lines.map(PresupuestoItemRow.fromLine).toList();
    while (rows.length < PresupuestoBranding.paperRows) {
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
    );
  }

  final String day;
  final String month;
  final String year;
  final BudgetCustomer customer;
  final PresupuestoSummary summary;
  final List<PresupuestoItemRow> tableRows;
  final String? sellerName;
}
