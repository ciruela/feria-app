import 'package:flutter/material.dart';

import '../../models/budget.dart';
import '../../models/budget_customer_controllers.dart';
import '../../models/presupuesto_document.dart';
import '../../models/urban_receipt_options.dart';
import 'presupuesto_items_table.dart';
import 'urban_table_watermark.dart';

/// Layout Urban Tactical fiel al PDF de referencia (Recibo-urban.pdf).
class PresupuestoUrbanPaper extends StatelessWidget {
  const PresupuestoUrbanPaper({
    super.key,
    required this.document,
    required this.controllers,
    required this.readOnly,
    required this.onSerialChanged,
    this.onChanged,
  });

  final PresupuestoDocument document;
  final BudgetCustomerControllers controllers;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final branding = document.branding;
    final summary = document.summary;

    // AR-59: Clip evita franjas si el pie aprieta; la tabla ya hace fit-to-page.
    // Marca de agua a página completa (no solo detrás de la tabla).
    return ClipRect(
      child: UrbanTableWatermark(
        branding: branding,
        width: 360,
        opacity: 0.16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UrbanBox(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branding.companyName,
                          style: _urbanText(13, weight: FontWeight.w900),
                        ),
                        Text(
                          branding.addressLine,
                          style: _urbanText(8.5),
                        ),
                        if (branding.taxLine.isNotEmpty)
                          Text(
                            branding.taxLine,
                            style: _urbanText(8.5, weight: FontWeight.w800),
                          ),
                        Text(
                          branding.phoneLine,
                          style: _urbanText(8.5),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          branding.documentTitle,
                          textAlign: TextAlign.right,
                          style: _urbanText(12, weight: FontWeight.w900),
                        ),
                        Text(
                          branding.documentSubtitle,
                          textAlign: TextAlign.right,
                          style: _urbanText(7, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fecha: ${document.formattedDate}',
                          style: _urbanText(8.5, weight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _UrbanBox(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _UrbanField(
                            label: 'CLIENTE:',
                            controller: controllers.fullName,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                          _UrbanField(
                            label: 'NRO CLU :',
                            controller: controllers.clu,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                          _UrbanField(
                            label: 'TELEFONO:',
                            controller: controllers.phone,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                          _UrbanDomicilioField(
                            controllers: controllers,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                      width: 16,
                      thickness: 1,
                      color: Colors.black,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _UrbanReadOnlyField(
                            label: 'MÉTODO DE PAGO:',
                            value: summary.paymentAbbrevFor(document.branding),
                          ),
                          _UrbanField(
                            label: 'CUIT:',
                            controller: controllers.dni,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                          _UrbanFiscalConditionField(
                            controller: controllers.fiscalCondition,
                            readOnly: readOnly,
                            onChanged: onChanged,
                          ),
                          _UrbanField(
                            label: 'Obs:',
                            controller: controllers.notes,
                            readOnly: readOnly,
                            onChanged: onChanged,
                            minLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return PresupuestoItemsTable(
                    branding: branding,
                    rows: document.tableRows,
                    readOnly: readOnly,
                    onSerialChanged: onSerialChanged,
                    onTcChanged: (_, __) {},
                    bodyHeight: constraints.maxHeight,
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: _UrbanBox(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total:',
                      style: _urbanText(10, weight: FontWeight.w900),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      summary.formattedCombinedTotal,
                      style: _urbanText(10, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Recibo ${document.formattedDate}',
                    style: _urbanText(9, weight: FontWeight.w800),
                  ),
                ),
                _UrbanBox(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    'Saldo: Abonó total',
                    style: _urbanText(8, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _UrbanStatusGrid(checks: branding.urbanStatusChecks),
            const SizedBox(height: 10),
            const _UrbanDashedRule(),
            const SizedBox(height: 8),
            Text(
              branding.signatureLine,
              textAlign: TextAlign.center,
              style: _urbanText(8, weight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Fecha:', style: _urbanText(8, weight: FontWeight.w900)),
                const SizedBox(width: 6),
                Expanded(child: Container(height: 1, color: Colors.black)),
                const SizedBox(width: 20),
                Text('FIRMA:', style: _urbanText(8, weight: FontWeight.w900)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2, child: Container(height: 1, color: Colors.black)),
              ],
            ),
            if (document.sellerName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Atendido por: ${document.sellerName}',
                style: _urbanText(8, weight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static TextStyle _urbanText(
    double size, {
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(fontSize: size, fontWeight: weight, height: 1.15);
  }
}

class _UrbanBox extends StatelessWidget {
  const _UrbanBox(
      {required this.child, this.padding = const EdgeInsets.all(8)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: child,
    );
  }
}

class _UrbanReadOnlyField extends StatelessWidget {
  const _UrbanReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 0.9),
                ),
              ),
              child: Text(
                value.isEmpty ? ' ' : value,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrbanField extends StatelessWidget {
  const _UrbanField({
    required this.label,
    required this.controller,
    required this.readOnly,
    this.onChanged,
    this.minLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    // AR-51: comprobante read-only must not use TextField (dark fill bands).
    if (readOnly) {
      return _UrbanReadOnlyField(label: label, value: controller.text);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: minLines,
              maxLines: minLines,
              onChanged: (_) => onChanged?.call(),
              cursorColor: Colors.black,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.only(bottom: 1),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 0.9),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 0.9),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrbanDomicilioField extends StatefulWidget {
  const _UrbanDomicilioField({
    required this.controllers,
    required this.readOnly,
    this.onChanged,
  });

  final BudgetCustomerControllers controllers;
  final bool readOnly;
  final VoidCallback? onChanged;

  @override
  State<_UrbanDomicilioField> createState() => _UrbanDomicilioFieldState();
}

class _UrbanDomicilioFieldState extends State<_UrbanDomicilioField> {
  String get _combinedLine {
    return BudgetCustomer(
      address: widget.controllers.address.text,
      city: widget.controllers.city.text,
    ).domicilioLine;
  }

  /// AR-58: Urban tiene un solo campo DOMICILIO. Si el OCR dejó calle/localidad
  /// separados, los unimos en `address` para que el usuario vea y edite todo.
  void _mergeCityIntoAddressIfNeeded() {
    if (widget.readOnly) return;
    final merged = BudgetCustomer(
      address: widget.controllers.address.text,
      city: widget.controllers.city.text,
    ).mergeDomicilioIntoAddress();
    if (widget.controllers.city.text.trim().isEmpty &&
        widget.controllers.address.text == merged.address) {
      return;
    }
    widget.controllers.address.text = merged.address;
    widget.controllers.city.text = merged.city;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mergeCityIntoAddressIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant _UrbanDomicilioField oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mergeCityIntoAddressIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      return _UrbanReadOnlyField(label: 'DOMICILIO:', value: _combinedLine);
    }

    return _UrbanField(
      label: 'DOMICILIO:',
      controller: widget.controllers.address,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
    );
  }
}

class _UrbanFiscalConditionField extends StatelessWidget {
  const _UrbanFiscalConditionField({
    required this.controller,
    required this.readOnly,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim().isEmpty
        ? UrbanReceiptOptions.defaultFiscalCondition
        : controller.text.trim();

    if (readOnly) {
      return _UrbanReadOnlyField(label: 'CONDICION FISCAL:', value: value);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'CONDICION FISCAL:',
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: UrbanReceiptOptions.fiscalConditions.contains(value)
                  ? value
                  : UrbanReceiptOptions.defaultFiscalCondition,
              isExpanded: true,
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.black,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.only(bottom: 1),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 0.9),
                ),
              ),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              items: [
                for (final option in UrbanReceiptOptions.fiscalConditions)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (selected) {
                if (selected == null) return;
                controller.text = selected;
                onChanged?.call();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UrbanStatusGrid extends StatelessWidget {
  const _UrbanStatusGrid({required this.checks});

  final List<String> checks;

  @override
  Widget build(BuildContext context) {
    if (checks.isEmpty) return const SizedBox.shrink();

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1),
      columnWidths: const {
        0: FlexColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (var i = 0; i < checks.length; i += 2)
          TableRow(
            children: [
              _UrbanStatusCell(label: checks[i]),
              if (i + 1 < checks.length)
                _UrbanStatusCell(label: checks[i + 1])
              else
                const SizedBox.shrink(),
            ],
          ),
      ],
    );
  }
}

class _UrbanStatusCell extends StatelessWidget {
  const _UrbanStatusCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrbanDashedRule extends StatelessWidget {
  const _UrbanDashedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final dashCount =
            (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < dashCount; i++)
              Container(
                width: dashWidth,
                height: 1,
                color: Colors.black,
              ),
          ],
        );
      },
    );
  }
}
