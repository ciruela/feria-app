import 'package:flutter/material.dart';

import '../../models/presupuesto_document.dart';
import '../../utils/uppercase_input.dart';

class PresupuestoItemsTable extends StatelessWidget {
  const PresupuestoItemsTable({
    super.key,
    required this.rows,
    required this.readOnly,
    required this.onSerialChanged,
  });

  final List<PresupuestoItemRow> rows;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;

  @override
  Widget build(BuildContext context) {
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
          children: [
            for (final header in PresupuestoBranding.tableHeaders)
              _HeaderCell(header),
          ],
        ),
        ...rows.map(_buildRow),
      ],
    );
  }

  TableRow _buildRow(PresupuestoItemRow row) {
    if (row.isEmpty) {
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
        _BodyCell(row.code, align: TextAlign.center),
        _BodyCell('${row.quantity}', align: TextAlign.center),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.detail,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (row.isArma) ...[
                const SizedBox(height: 4),
                _SerialInlineField(
                  lineKey: row.lineKey,
                  initialValue: row.serialNumber,
                  readOnly: readOnly,
                  onChanged: onSerialChanged,
                ),
              ],
            ],
          ),
        ),
        _BodyCell(row.unitPrice, align: TextAlign.right),
        _BodyCell(row.lineTotal, align: TextAlign.right),
      ],
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
