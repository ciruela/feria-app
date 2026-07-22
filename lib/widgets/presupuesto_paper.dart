import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_customer_controllers.dart';
import '../models/product_prices.dart';
import '../utils/formatters.dart';
import '../utils/uppercase_input.dart';

class PresupuestoPaper extends StatelessWidget {
  const PresupuestoPaper({
    super.key,
    required this.budget,
    required this.controllers,
    required this.onSerialChanged,
    this.readOnly = false,
    this.onChanged,
  });

  final Budget budget;
  final BudgetCustomerControllers controllers;
  final void Function(String lineKey, String value) onSerialChanged;
  final bool readOnly;
  final VoidCallback? onChanged;

  static const _paperRows = 14;

  @override
  Widget build(BuildContext context) {
    final date = budget.date;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderSection(day: day, month: month, year: year),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'SEÑOR/A:',
            controller: controllers.fullName,
            readOnly: readOnly,
            onChanged: onChanged,
          ),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _LabeledField(
                  label: 'DNI:',
                  controller: controllers.dni,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
              Expanded(
                child: _LabeledField(
                  label: 'CLU:',
                  controller: controllers.clu,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
              Expanded(
                child: _LabeledField(
                  label: 'VTO:',
                  controller: controllers.cluExpiry,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'TEL:',
                  controller: controllers.phone,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
              Expanded(
                child: _LabeledField(
                  label: 'MAIL:',
                  controller: controllers.email,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _LabeledField(
                  label: 'DOMICILIO:',
                  controller: controllers.address,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
              Expanded(
                flex: 2,
                child: _LabeledField(
                  label: 'LOCALIDAD:',
                  controller: controllers.city,
                  readOnly: readOnly,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ItemsTable(
            lines: budget.lines,
            readOnly: readOnly,
            onSerialChanged: onSerialChanged,
          ),
          const SizedBox(height: 8),
          _TotalSection(budget: budget),
          const SizedBox(height: 8),
          _LabeledField(
            label: 'OBS:',
            controller: controllers.notes,
            readOnly: readOnly,
            onChanged: onChanged,
            minLines: 2,
          ),
          const SizedBox(height: 10),
          _PaymentChecks(methods: budget.paymentMethods),
          if (budget.sellerName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Atendido por: ${budget.sellerName}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.day,
    required this.month,
    required this.year,
  });

  final String day;
  final String month;
  final String year;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          height: 78,
          child: CustomPaint(
            painter: _LogoPainter(),
            child: const Center(
              child: Text(
                'WORLD\nGUNS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'WORLD GUNS S.R.L.',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              Text(
                'ARMERIA - CUCHILLERIA - ACCESORIOS',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800),
              ),
              Text(
                'GESTORIA ANMAC P/CIVILES - FUERZAS-EMPRESAS',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 2),
              Text(
                'Triunvirato 2589 1 Piso (Villa Luzuriaga - Pcia. Bs.As.)',
                style: TextStyle(fontSize: 8.5),
              ),
              Text(
                'Tel: 4835-9420  Ventas WApp: 11-3864-4279',
                style: TextStyle(fontSize: 8.5),
              ),
              Text(
                'Adm./Gestoria WApp: 11-5147-1705  @wordguns.srl',
                style: TextStyle(fontSize: 8.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'PRESUPUESTO',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const Text(
                '(DOC. NO VALIDO COMO FACTURA)',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DateBox(value: day),
                  const SizedBox(width: 4),
                  _DateBox(value: month),
                  const SizedBox(width: 4),
                  _DateBox(value: year, wide: true),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Horario: Lun a Vie 10 a 13 y 15:30 a 19 · Sab 10 a 13\n'
                'Los precios pueden variar sin previo aviso.\n'
                'Reserva de mercaderia con seña del 30%.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 6.5, height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.value, this.wide = false});

  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 42 : 28,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, size.width / 2 - 2, paint);
    canvas.drawLine(
      Offset(center.dx, 4),
      Offset(center.dx, size.height - 4),
      paint,
    );
    canvas.drawLine(
      Offset(4, center.dy),
      Offset(size.width - 4, center.dy),
      paint,
    );
    canvas.drawCircle(center, 6, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              minLines: minLines,
              maxLines: minLines,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: UpperCaseTextFormatter.formatters,
              onChanged: (_) => onChanged?.call(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.only(bottom: 2),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.2),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.2),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  const _ItemsTable({
    required this.lines,
    required this.readOnly,
    required this.onSerialChanged,
  });

  final List<BudgetLine> lines;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;

  @override
  Widget build(BuildContext context) {
    final rows = <BudgetLine?>[...lines];
    while (rows.length < PresupuestoPaper._paperRows) {
      rows.add(null);
    }

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1.2),
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FixedColumnWidth(38),
        2: FlexColumnWidth(),
        3: FixedColumnWidth(78),
        4: FixedColumnWidth(86),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade300),
          children: const [
            _HeaderCell('COD'),
            _HeaderCell('CANT'),
            _HeaderCell('DETALLE'),
            _HeaderCell('P. UNIT'),
            _HeaderCell('IMPORTE'),
          ],
        ),
        ...rows.map((line) {
          if (line == null) {
            return const TableRow(
              children: [
                _BodyCell(''),
                _BodyCell(''),
                _BodyCell(''),
                _BodyCell(''),
                _BodyCell(''),
              ],
            );
          }

          return TableRow(
            children: [
              _BodyCell(line.code, align: TextAlign.center),
              _BodyCell('${line.quantity}', align: TextAlign.center),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.detail,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (line.isArma && (line.splitPart == null || line.splitPart == 1)) ...[
                      const SizedBox(height: 4),
                      _SerialInlineField(
                        lineKey: line.lineKey,
                        initialValue: line.serialNumber,
                        readOnly: readOnly,
                        onChanged: onSerialChanged,
                      ),
                    ],
                  ],
                ),
              ),
              _BodyCell(line.formattedUnitPlain, align: TextAlign.right),
              _BodyCell(line.formattedLinePlain, align: TextAlign.right),
            ],
          );
        }),
      ],
    );
  }
}

class _TotalSection extends StatelessWidget {
  const _TotalSection({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final totals = <Widget>[];

    if (budget.hasUsdPayments) {
      totals.add(
        _TotalBox(
          label: 'TOTAL U\$S',
          value: formatUsd(budget.totalUsdLines).replaceAll('USD ', ''),
        ),
      );
    }
    if (budget.hasArsPayments) {
      totals.add(
        _TotalBox(
          label: 'TOTAL \$',
          value: formatArs(budget.totalArsLines).replaceAll(r'$ ', ''),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < totals.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              totals[i],
            ],
          ],
        ),
      ],
    );
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.align = TextAlign.left});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SerialInlineField extends StatefulWidget {
  const _SerialInlineField({
    required this.lineKey,
    required this.initialValue,
    required this.readOnly,
    required this.onChanged,
  });

  final String lineKey;
  final String initialValue;
  final bool readOnly;
  final void Function(String lineKey, String value) onChanged;

  @override
  State<_SerialInlineField> createState() => _SerialInlineFieldState();
}

class _SerialInlineFieldState extends State<_SerialInlineField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_SerialInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text &&
        widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'SERIE:',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _controller,
            readOnly: widget.readOnly,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: UpperCaseTextFormatter.formatters,
            onChanged: (value) => widget.onChanged(widget.lineKey, value),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'N° serie',
              contentPadding: EdgeInsets.only(bottom: 1),
              border: UnderlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentChecks extends StatelessWidget {
  const _PaymentChecks({required this.methods});

  final Set<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _Check(label: 'EFVO.', checked: methods.contains(PaymentMethod.efectivo)),
            _Check(label: 'DEBITO', checked: methods.contains(PaymentMethod.debito)),
            _Check(
              label: 'TRANSFERENCIA',
              checked: methods.contains(PaymentMethod.transferencia),
            ),
            _Check(label: 'PESOS', checked: _usesPesos(methods)),
            _Check(label: 'U\$s', checked: methods.contains(PaymentMethod.dolarBillete)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'TARJETAS DE CREDITO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Check(label: '1 CTA', checked: methods.contains(PaymentMethod.tarjeta1)),
                  _Check(label: '3 CTAS', checked: methods.contains(PaymentMethod.tarjeta3)),
                  _Check(label: '6 CTAS', checked: methods.contains(PaymentMethod.tarjeta6)),
                  _Check(label: '9 CTAS', checked: methods.contains(PaymentMethod.tarjeta9)),
                  _Check(label: '12 CTAS', checked: methods.contains(PaymentMethod.tarjeta12)),
                  _Check(label: '18 CTAS', checked: methods.contains(PaymentMethod.tarjeta18)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _usesPesos(Set<PaymentMethod> methods) {
    return methods.contains(PaymentMethod.lista) ||
        methods.contains(PaymentMethod.transferencia) ||
        methods.contains(PaymentMethod.efectivo) ||
        methods.contains(PaymentMethod.debito) ||
        methods.any((method) => method.name.startsWith('tarjeta'));
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: checked
              ? const Text('X', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900))
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
