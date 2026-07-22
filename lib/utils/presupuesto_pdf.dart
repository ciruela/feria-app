import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/budget.dart';
import '../models/product_prices.dart';
import 'formatters.dart';

class PresupuestoPdf {
  static const _paperRows = 14;

  static Future<Uint8List> generate(Budget budget) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        build: (context) => _buildPage(budget),
      ),
    );
    return doc.save();
  }

  static Future<void> printBudget(Budget budget) async {
    await Printing.layoutPdf(
      name: fileName(budget),
      onLayout: (_) => generate(budget),
    );
  }

  static Future<void> share(Budget budget) async {
    final bytes = await generate(budget);
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName(budget),
    );
  }

  static String fileName(Budget budget) {
    final date = budget.date;
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final customer = budget.customer.fullName
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final suffix = customer.isEmpty ? '' : '-$customer';
    return 'presupuesto-worldguns-$stamp$suffix.pdf';
  }

  static pw.Widget _buildPage(Budget budget) {
    final date = budget.date;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final customer = budget.customer;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header(day: day, month: month, year: year),
          pw.SizedBox(height: 8),
          _fieldRow('SEÑOR/A:', customer.fullName, flex: 1),
          pw.Row(
            children: [
              pw.Expanded(flex: 2, child: _fieldRow('DNI:', customer.dni)),
              pw.Expanded(child: _fieldRow('CLU:', customer.clu)),
              pw.Expanded(child: _fieldRow('VTO:', customer.cluExpiry)),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(child: _fieldRow('TEL:', customer.phone)),
              pw.Expanded(child: _fieldRow('MAIL:', customer.email)),
            ],
          ),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: _fieldRow('DOMICILIO:', customer.address),
              ),
              pw.Expanded(
                flex: 2,
                child: _fieldRow('LOCALIDAD:', customer.city),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          _itemsTable(budget),
          pw.SizedBox(height: 6),
          _totals(budget),
          pw.SizedBox(height: 6),
          _fieldRow('OBS:', customer.notes, minHeight: 28),
          pw.SizedBox(height: 8),
          _paymentChecks(budget.paymentMethods),
          if (budget.sellerName != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Atendido por: ${budget.sellerName}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _header({
    required String day,
    required String month,
    required String year,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 56,
          height: 56,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: PdfColors.black, width: 1.5),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            'WORLD\nGUNS',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 1,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WORLD GUNS S.R.L.',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'ARMERIA - CUCHILLERIA - ACCESORIOS',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'GESTORIA ANMAC P/CIVILES - FUERZAS-EMPRESAS',
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Triunvirato 2589 1 Piso (Villa Luzuriaga - Pcia. Bs.As.)',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                'Tel: 4835-9420  Ventas WApp: 11-3864-4279',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                'Adm./Gestoria WApp: 11-5147-1705  @wordguns.srl',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 108,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PRESUPUESTO',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                '(DOC. NO VALIDO COMO FACTURA)',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  _dateBox(day),
                  pw.SizedBox(width: 3),
                  _dateBox(month),
                  pw.SizedBox(width: 3),
                  _dateBox(year, wide: true),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Horario: Lun a Vie 10 a 13 y 15:30 a 19 · Sab 10 a 13\n'
                'Los precios pueden variar sin previo aviso.\n'
                'Reserva de mercaderia con seña del 30%.',
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 5.8, lineSpacing: 1.1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _dateBox(String value, {bool wide = false}) {
    return pw.Container(
      width: wide ? 36 : 22,
      height: 18,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _fieldRow(
    String label,
    String value, {
    int flex = 1,
    double minHeight = 14,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, right: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(width: 3),
          pw.Expanded(
            child: pw.Container(
              constraints: pw.BoxConstraints(minHeight: minHeight),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                ),
              ),
              alignment: pw.Alignment.bottomLeft,
              padding: const pw.EdgeInsets.only(bottom: 1),
              child: pw.Text(
                _display(value),
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(Budget budget) {
    final rows = <BudgetLine?>[...budget.lines];
    while (rows.length < _paperRows) {
      rows.add(null);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FixedColumnWidth(42),
        1: const pw.FixedColumnWidth(28),
        2: const pw.FlexColumnWidth(),
        3: const pw.FixedColumnWidth(58),
        4: const pw.FixedColumnWidth(62),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _headerCell('COD'),
            _headerCell('CANT'),
            _headerCell('DETALLE'),
            _headerCell('P. UNIT'),
            _headerCell('IMPORTE'),
          ],
        ),
        ...rows.map((line) {
          if (line == null) {
            return pw.TableRow(
              children: List.generate(5, (_) => _bodyCell('')),
            );
          }

          var detail = line.detail;
          if (line.isArma &&
              line.serialNumber.trim().isNotEmpty &&
              (line.splitPart == null || line.splitPart == 1)) {
            detail = '$detail\nSERIE: ${line.serialNumber.trim()}';
          }

          return pw.TableRow(
            children: [
              _bodyCell(line.code, align: pw.TextAlign.center),
              _bodyCell('${line.quantity}', align: pw.TextAlign.center),
              _bodyCell(detail),
              _bodyCell(line.formattedUnitPlain, align: pw.TextAlign.right),
              _bodyCell(line.formattedLinePlain, align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _headerCell(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _bodyCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }

  static pw.Widget _paymentChecks(Set<PaymentMethod> methods) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _check('EFVO.', methods.contains(PaymentMethod.efectivo)),
            _check('DEBITO', methods.contains(PaymentMethod.debito)),
            _check('TRANSFERENCIA', methods.contains(PaymentMethod.transferencia)),
            _check('PESOS', _usesPesos(methods)),
            _check('U\$s', methods.contains(PaymentMethod.dolarBillete)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TARJETAS DE CREDITO',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Wrap(
                spacing: 6,
                runSpacing: 3,
                children: [
                  _check('1 CTA', methods.contains(PaymentMethod.tarjeta1)),
                  _check('3 CTAS', methods.contains(PaymentMethod.tarjeta3)),
                  _check('6 CTAS', methods.contains(PaymentMethod.tarjeta6)),
                  _check('9 CTAS', methods.contains(PaymentMethod.tarjeta9)),
                  _check('12 CTAS', methods.contains(PaymentMethod.tarjeta12)),
                  _check('18 CTAS', methods.contains(PaymentMethod.tarjeta18)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _check(String label, bool checked) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 0.8),
          ),
          child: checked
              ? pw.Text('X', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
              : null,
        ),
        pw.SizedBox(width: 3),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _totals(Budget budget) {
    final boxes = <pw.Widget>[];

    if (budget.hasUsdPayments) {
      boxes.add(
        _totalBox(
          'TOTAL U\$S ${_formatUsd(budget.totalUsdLines)}',
        ),
      );
    }
    if (budget.hasArsPayments) {
      boxes.add(
        _totalBox(
          'TOTAL \$ ${_formatTotal(budget.totalArsLines)}',
        ),
      );
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 4),
            boxes[i],
          ],
        ],
      ),
    );
  }

  static pw.Widget _totalBox(String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.5),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static String _display(String value) => value.isEmpty ? ' ' : value;

  static String _formatTotal(double value) {
    return formatArs(value).replaceAll(r'$ ', '');
  }

  static String _formatUsd(double value) {
    return formatUsd(value).replaceAll('USD ', '');
  }

  static bool _usesPesos(Set<PaymentMethod> methods) {
    return methods.contains(PaymentMethod.lista) ||
        methods.contains(PaymentMethod.transferencia) ||
        methods.contains(PaymentMethod.efectivo) ||
        methods.contains(PaymentMethod.debito) ||
        methods.any((method) => method.name.startsWith('tarjeta'));
  }
}
