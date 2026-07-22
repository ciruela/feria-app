import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/budget.dart';
import '../models/presupuesto_document.dart';
import '../models/presupuesto_summary.dart';

class PresupuestoPdf {
  static Future<Uint8List> generate(Budget budget) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        build: (context) => _buildPage(PresupuestoDocument.fromBudget(budget)),
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

  static pw.Widget _buildPage(PresupuestoDocument document) {
    final customer = document.customer;
    final summary = document.summary;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.8),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _header(document),
          pw.SizedBox(height: 8),
          _fieldRow('SEÑOR/A:', customer.fullName),
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
          _itemsTable(document.tableRows),
          pw.SizedBox(height: 6),
          _totals(summary),
          if (summary.paymentAllocationLines.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _paymentAllocations(summary.paymentAllocationLines),
          ],
          pw.SizedBox(height: 6),
          _fieldRow('OBS:', customer.notes, minHeight: 28),
          pw.SizedBox(height: 8),
          _paymentChecks(summary),
          if (document.sellerName != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Atendido por: ${document.sellerName}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _header(PresupuestoDocument document) {
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
                PresupuestoBranding.companyName,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                PresupuestoBranding.businessLine,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                PresupuestoBranding.servicesLine,
                style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                PresupuestoBranding.addressLine,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                PresupuestoBranding.phoneLine,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                PresupuestoBranding.adminLine,
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
                PresupuestoBranding.documentTitle,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                PresupuestoBranding.documentSubtitle,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  _dateBox(document.day),
                  pw.SizedBox(width: 3),
                  _dateBox(document.month),
                  pw.SizedBox(width: 3),
                  _dateBox(document.year, wide: true),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                PresupuestoBranding.footerNote,
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

  static pw.Widget _itemsTable(List<PresupuestoItemRow> rows) {
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
            for (final header in PresupuestoBranding.tableHeaders)
              _headerCell(header),
          ],
        ),
        ...rows.map((row) {
          if (row.isEmpty) {
            return pw.TableRow(
              children: List.generate(5, (_) => _bodyCell('')),
            );
          }

          return pw.TableRow(
            children: [
              _bodyCell(row.code, align: pw.TextAlign.center),
              _bodyCell('${row.quantity}', align: pw.TextAlign.center),
              _bodyCell(row.detailWithSerial),
              _bodyCell(row.unitPrice, align: pw.TextAlign.right),
              _bodyCell(row.lineTotal, align: pw.TextAlign.right),
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

  static pw.Widget _paymentAllocations(List<PaymentAllocationLine> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            PresupuestoBranding.paymentAllocationTitle,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '· ${line.label}: ${line.amount}',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentChecks(PresupuestoSummary summary) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final check in summary.primaryPaymentChecks)
              _check(check.label, check.checked),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              PresupuestoBranding.creditCardsTitle,
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Wrap(
                spacing: 6,
                runSpacing: 3,
                children: [
                  for (final check in summary.creditCardChecks)
                    _check(check.label, check.checked),
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
              ? pw.Text(
                  'X',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                )
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

  static pw.Widget _totals(PresupuestoSummary summary) {
    final boxes = <pw.Widget>[];

    if (summary.hasUsdTotal) {
      boxes.add(_totalBox('TOTAL U\$S ${summary.formattedUsdTotal}'));
    }
    if (summary.hasArsTotal) {
      boxes.add(_totalBox('TOTAL \$ ${summary.formattedArsTotal}'));
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
}
