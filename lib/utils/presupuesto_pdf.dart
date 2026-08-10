import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/budget.dart';
import '../models/presupuesto_document.dart';
import '../models/presupuesto_summary.dart';
import 'presupuesto_page_format.dart';
import 'presupuesto_row_heights.dart';
import 'share_pdf.dart';

class PresupuestoPdf {
  static pw.MemoryImage? _urbanWatermarkImage;
  static String? _urbanWatermarkAsset;

  static Future<Uint8List> generate(
    Budget budget, {
    required PresupuestoBranding branding,
  }) async {
    pw.MemoryImage? urbanWatermark;
    if (branding.isUrban) {
      urbanWatermark = await _loadUrbanWatermark(branding);
    }

    final doc = pw.Document();
    final document = PresupuestoDocument.fromBudget(budget, branding: branding);
    doc.addPage(
      pw.Page(
        pageFormat: PresupuestoPageFormat.pdf,
        margin: const pw.EdgeInsets.symmetric(
          horizontal: PresupuestoPageFormat.marginHorizontal,
          vertical: PresupuestoPageFormat.marginVertical,
        ),
        build: (context) => pw.SizedBox(
          height: PresupuestoPageFormat.innerHeight,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 1.8),
            ),
            padding:
                const pw.EdgeInsets.all(PresupuestoPageFormat.borderPadding),
            child: document.branding.isUrban
                ? _buildUrbanPage(document, watermark: urbanWatermark)
                : _buildStandardPage(document),
          ),
        ),
      ),
    );
    return doc.save();
  }

  static Future<pw.MemoryImage?> _loadUrbanWatermark(
    PresupuestoBranding branding,
  ) async {
    final asset = branding.watermarkLogoAsset;
    if (asset == null) return null;
    if (_urbanWatermarkAsset != asset) {
      _urbanWatermarkImage = null;
      _urbanWatermarkAsset = asset;
    }
    _urbanWatermarkImage ??= pw.MemoryImage(
      (await rootBundle.load(asset)).buffer.asUint8List(),
    );
    return _urbanWatermarkImage;
  }

  static Future<void> printBudget(
    Budget budget, {
    required PresupuestoBranding branding,
  }) async {
    await Printing.layoutPdf(
      name: fileName(budget, branding: branding),
      onLayout: (_) => generate(budget, branding: branding),
    );
  }

  static Future<void> share(
    Budget budget, {
    required PresupuestoBranding branding,
  }) async {
    final bytes = await generate(budget, branding: branding);
    await sharePdfBytes(
      bytes: bytes,
      filename: fileName(budget, branding: branding),
    );
  }

  static String fileName(
    Budget budget, {
    required PresupuestoBranding branding,
  }) {
    final date = budget.date;
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final customer = budget.customer.fullName
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
    final suffix = customer.isEmpty ? '' : '-$customer';
    return '${branding.fileNamePrefix}-$stamp$suffix.pdf';
  }

  static pw.Widget _buildStandardPage(PresupuestoDocument document) {
    final customer = document.customer;
    final summary = document.summary;
    final branding = document.branding;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _standardHeader(document),
        pw.SizedBox(height: 6),
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
        pw.SizedBox(height: 4),
        pw.Expanded(
          child: pw.LayoutBuilder(
            builder: (context, constraints) => _detailedItemsTable(
              document.tableRows,
              branding,
              bodyHeight: constraints?.maxHeight,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        _totals(summary),
        if (summary.paymentAllocationLines.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _paymentAllocations(summary.paymentAllocationLines, branding),
        ],
        pw.SizedBox(height: 4),
        _fieldRow('OBS:', customer.notes, minHeight: 22),
        pw.SizedBox(height: 4),
        _paymentChecks(summary, branding),
        if (document.sellerName != null) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Atendido por: ${document.sellerName}',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildUrbanPage(
    PresupuestoDocument document, {
    pw.MemoryImage? watermark,
  }) {
    final customer = document.customer;
    final summary = document.summary;
    final branding = document.branding;

    final page = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _urbanBox(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      branding.companyName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      branding.addressLine,
                      style: const pw.TextStyle(fontSize: 7.5),
                    ),
                    if (branding.taxLine.isNotEmpty)
                      pw.Text(
                        branding.taxLine,
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.Text(
                      branding.phoneLine,
                      style: const pw.TextStyle(fontSize: 7.5),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      branding.documentTitle,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      branding.documentSubtitle,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 6.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Fecha: ${document.formattedDate}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        _urbanBox(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _fieldRow('CLIENTE:', customer.fullName),
                    _fieldRow('NRO CLU :', customer.clu),
                    _fieldRow('TELEFONO:', customer.phone),
                    _fieldRow('DOMICILIO:', customer.domicilioLine),
                  ],
                ),
              ),
              pw.Container(
                width: 1,
                height: 72,
                color: PdfColors.black,
                margin: const pw.EdgeInsets.symmetric(horizontal: 6),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _fieldRow(
                        'MÉTODO DE PAGO:', summary.paymentAbbrevFor(branding)),
                    _fieldRow('CUIT:', customer.dni),
                    _fieldRow(
                      'CONDICION FISCAL:',
                      summary.fiscalConditionFor(branding),
                    ),
                    _fieldRow('Obs:', customer.notes, minHeight: 22),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.LayoutBuilder(
            builder: (context, constraints) => _simpleItemsTable(
              document.tableRows,
              bodyHeight: constraints?.maxHeight,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _urbanBox(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Total:',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 24),
                pw.Text(
                  summary.formattedCombinedTotal,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'Recibo ${document.formattedDate}',
                style:
                    pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
            _urbanBox(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: pw.Text(
                'Saldo: Abonó total',
                style:
                    pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _urbanStatusGrid(branding.urbanStatusChecks),
        pw.SizedBox(height: 10),
        _urbanDashedRule(),
        pw.SizedBox(height: 8),
        pw.Text(
          branding.signatureLine,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Text(
              'Fecha:',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(child: pw.Divider(thickness: 0.8)),
            pw.SizedBox(width: 16),
            pw.Text(
              'FIRMA:',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(flex: 2, child: pw.Divider(thickness: 0.8)),
          ],
        ),
        if (document.sellerName != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            'Atendido por: ${document.sellerName}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ],
    );

    if (watermark == null) return page;

    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Center(
          child: pw.Opacity(
            opacity: 0.16,
            child: pw.Image(watermark, width: 320),
          ),
        ),
        page,
      ],
    );
  }

  static pw.Widget _urbanBox({
    required pw.Widget child,
    pw.EdgeInsets padding = const pw.EdgeInsets.all(8),
  }) {
    return pw.Container(
      padding: padding,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.9),
      ),
      child: child,
    );
  }

  static pw.Widget _urbanDashedRule() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List.generate(
        42,
        (_) => pw.Container(
          width: 5,
          height: 0.8,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _standardHeader(PresupuestoDocument document) {
    final branding = document.branding;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (branding.logoText.isNotEmpty)
          pw.Container(
            width: 56,
            height: 56,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColors.black, width: 1.5),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              branding.logoText,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: branding.isWorldGuns ? 7 : 9,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 1,
              ),
            ),
          ),
        if (branding.logoText.isNotEmpty) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                branding.companyName,
                style:
                    pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              if (branding.businessLine.isNotEmpty)
                pw.Text(
                  branding.businessLine,
                  style:
                      pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                ),
              if (branding.servicesLine.isNotEmpty)
                pw.Text(
                  branding.servicesLine,
                  style:
                      pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                ),
              if (branding.addressLine.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(branding.addressLine,
                    style: const pw.TextStyle(fontSize: 7)),
              ],
              if (branding.phoneLine.isNotEmpty)
                pw.Text(branding.phoneLine,
                    style: const pw.TextStyle(fontSize: 7)),
              if (branding.adminLine.isNotEmpty)
                pw.Text(branding.adminLine,
                    style: const pw.TextStyle(fontSize: 7)),
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
                branding.documentTitle,
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                branding.documentSubtitle,
                textAlign: pw.TextAlign.right,
                style:
                    pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
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
              if (branding.footerNote.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  branding.footerNote,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(fontSize: 5.8, lineSpacing: 1.1),
                ),
              ],
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
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _tableHeaderHeight = 22.0;

  static pw.Widget _detailedItemsTable(
    List<PresupuestoItemRow> rows,
    PresupuestoBranding branding, {
    double? bodyHeight,
  }) {
    final heights = PresupuestoRowHeights.resolve(
      rows: rows,
      bodyHeight: bodyHeight,
      headerHeight: _tableHeaderHeight,
      armaPref: 34,
      normalPref: 20,
      fillerPref: 20,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FixedColumnWidth(42),
        1: const pw.FixedColumnWidth(28),
        2: const pw.FlexColumnWidth(),
        3: const pw.FixedColumnWidth(46),
        4: const pw.FixedColumnWidth(54),
        5: const pw.FixedColumnWidth(58),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            for (final header in branding.tableHeaders)
              pw.SizedBox(
                height: _tableHeaderHeight,
                child: _headerCell(header),
              ),
          ],
        ),
        ...rows.map((row) {
          if (row.isEmpty) {
            return pw.TableRow(
              children: List.generate(
                6,
                (_) =>
                    pw.SizedBox(height: heights.filler, child: _bodyCell('')),
              ),
            );
          }

          final height = heights.forRow(row);

          return pw.TableRow(
            children: [
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.code, align: pw.TextAlign.center),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell('${row.quantity}', align: pw.TextAlign.center),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.detailWithSerial),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.tc, align: pw.TextAlign.center),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.unitPrice, align: pw.TextAlign.right),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.lineTotal, align: pw.TextAlign.right),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _simpleItemsTable(
    List<PresupuestoItemRow> rows, {
    double? bodyHeight,
  }) {
    // AR-59: reparte el alto para que checks/firma debajo del total no se corten.
    final heights = PresupuestoRowHeights.resolve(
      rows: rows,
      bodyHeight: bodyHeight,
      headerHeight: _tableHeaderHeight,
      armaPref: 30,
      normalPref: 20,
      fillerPref: 20,
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FixedColumnWidth(70),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.SizedBox(
                height: _tableHeaderHeight, child: _headerCell('Concepto')),
            pw.SizedBox(height: _tableHeaderHeight, child: _headerCell('Cant')),
            pw.SizedBox(
                height: _tableHeaderHeight, child: _headerCell('Valor')),
          ],
        ),
        ...rows.map((row) {
          if (row.isEmpty) {
            return pw.TableRow(
              children: List.generate(
                3,
                (_) => pw.SizedBox(
                  height: heights.filler,
                  child: _bodyCell(''),
                ),
              ),
            );
          }

          final height = heights.forRow(row);

          return pw.TableRow(
            children: [
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.detailWithSerial),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell('${row.quantity}', align: pw.TextAlign.center),
              ),
              pw.SizedBox(
                height: height,
                child: _bodyCell(row.lineTotal, align: pw.TextAlign.right),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _urbanStatusGrid(List<String> checks) {
    if (checks.isEmpty) return pw.SizedBox.shrink();

    final rows = <pw.TableRow>[];
    for (var i = 0; i < checks.length; i += 2) {
      rows.add(
        pw.TableRow(
          children: [
            _urbanStatusCell(checks[i]),
            if (i + 1 < checks.length)
              _urbanStatusCell(checks[i + 1])
            else
              pw.SizedBox(),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: {
        0: const pw.FlexColumnWidth(),
        1: const pw.FlexColumnWidth(),
      },
      children: rows,
    );
  }

  static pw.Widget _urbanStatusCell(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4, right: 8),
      child: _check(label, false),
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

  static pw.Widget _bodyCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 7.5),
      ),
    );
  }

  static pw.Widget _paymentAllocations(
    List<PaymentAllocationLine> lines,
    PresupuestoBranding branding,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            branding.paymentAllocationTitle,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          ...lines.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '· ${line.displayText}',
                style:
                    pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _paymentChecks(
    PresupuestoSummary summary,
    PresupuestoBranding branding,
  ) {
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
              branding.creditCardsTitle,
              style:
                  pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
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
                  style:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
