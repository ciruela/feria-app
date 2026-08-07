import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/presupuesto_document.dart';
import '../../utils/uppercase_input.dart';
import 'urban_table_watermark.dart';

class PresupuestoItemsTable extends StatelessWidget {
  const PresupuestoItemsTable({
    super.key,
    required this.branding,
    required this.rows,
    required this.readOnly,
    required this.onSerialChanged,
    required this.onTcChanged,
    this.bodyHeight,
  });

  final PresupuestoBranding branding;
  final List<PresupuestoItemRow> rows;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;
  final void Function(String lineKey, String value) onTcChanged;
  final double? bodyHeight;

  static const _headerHeight = 26.0;

  static double rowHeightFor({
    required double bodyHeight,
    required int rowCount,
  }) {
    if (rowCount <= 0) return 22;
    return ((bodyHeight - _headerHeight) / rowCount).clamp(18, 48);
  }

  @override
  Widget build(BuildContext context) {
    if (branding.showsDetailedTable) {
      return _DetailedItemsTable(
        branding: branding,
        rows: rows,
        readOnly: readOnly,
        onSerialChanged: onSerialChanged,
        onTcChanged: onTcChanged,
        bodyHeight: bodyHeight,
      );
    }

    return _SimpleItemsTable(
      branding: branding,
      rows: rows,
      readOnly: readOnly,
      onSerialChanged: onSerialChanged,
      bodyHeight: bodyHeight,
    );
  }
}

class _SimpleItemsTable extends StatelessWidget {
  const _SimpleItemsTable({
    required this.branding,
    required this.rows,
    required this.readOnly,
    required this.onSerialChanged,
    this.bodyHeight,
  });

  final PresupuestoBranding branding;
  final List<PresupuestoItemRow> rows;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;
  final double? bodyHeight;

  @override
  Widget build(BuildContext context) {
    final rowHeight = bodyHeight == null
        ? (branding.isUrban ? 28.0 : 22.0)
        : PresupuestoItemsTable.rowHeightFor(
            bodyHeight: bodyHeight!,
            rowCount: rows.length,
          );

    return UrbanTableWatermark(
      branding: branding,
      child: Table(
        border: TableBorder.all(color: Colors.black, width: 1.2),
        columnWidths: const {
          0: FlexColumnWidth(),
          1: FixedColumnWidth(52),
          2: FixedColumnWidth(96),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey.shade300),
            children: [
              for (final header in branding.tableHeaders)
                SizedBox(
                  height: PresupuestoItemsTable._headerHeight,
                  child: _HeaderCell(header),
                ),
            ],
          ),
          ...rows.map((row) {
            final cellHeight =
                row.isArma ? (rowHeight + 16).clamp(rowHeight, 52.0) : rowHeight;

            if (row.isEmpty) {
              return TableRow(
                children: List.generate(
                  3,
                  (_) => SizedBox(
                    height: rowHeight,
                    child: const _BodyCell(''),
                  ),
                ),
              );
            }

            return TableRow(
              children: [
                SizedBox(
                  height: cellHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                ),
                SizedBox(
                  height: cellHeight,
                  child: _BodyCell('${row.quantity}', align: TextAlign.center),
                ),
                SizedBox(
                  height: cellHeight,
                  child: _BodyCell(row.lineTotal, align: TextAlign.right),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _DetailedItemsTable extends StatelessWidget {
  const _DetailedItemsTable({
    required this.branding,
    required this.rows,
    required this.readOnly,
    required this.onSerialChanged,
    required this.onTcChanged,
    this.bodyHeight,
  });

  final PresupuestoBranding branding;
  final List<PresupuestoItemRow> rows;
  final bool readOnly;
  final void Function(String lineKey, String value) onSerialChanged;
  final void Function(String lineKey, String value) onTcChanged;
  final double? bodyHeight;

  @override
  Widget build(BuildContext context) {
    final rowHeight = bodyHeight == null
        ? 22.0
        : PresupuestoItemsTable.rowHeightFor(
            bodyHeight: bodyHeight!,
            rowCount: rows.length,
          );

    return Table(
      border: TableBorder.all(color: Colors.black, width: 1.2),
      columnWidths: const {
        0: FixedColumnWidth(52),
        1: FixedColumnWidth(38),
        2: FlexColumnWidth(),
        3: FixedColumnWidth(50),
        4: FixedColumnWidth(72),
        5: FixedColumnWidth(82),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade300),
          children: [
            for (final header in branding.tableHeaders)
              SizedBox(
                height: PresupuestoItemsTable._headerHeight,
                child: _HeaderCell(header),
              ),
          ],
        ),
        ...rows.map((row) => _buildRow(row, rowHeight)),
      ],
    );
  }

  TableRow _buildRow(PresupuestoItemRow row, double rowHeight) {
    final cellHeight =
        row.isArma ? (rowHeight + 16).clamp(rowHeight, 52.0) : rowHeight;

    if (row.isEmpty) {
      return TableRow(
        children: List.generate(
          6,
          (_) => SizedBox(height: rowHeight, child: const _BodyCell('')),
        ),
      );
    }

    return TableRow(
      children: [
        SizedBox(
          height: cellHeight,
          child: _BodyCell(row.code, align: TextAlign.center),
        ),
        SizedBox(
          height: cellHeight,
          child: _BodyCell('${row.quantity}', align: TextAlign.center),
        ),
        SizedBox(
          height: cellHeight,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
        SizedBox(
          height: cellHeight,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: _TcInlineField(
              lineKey: row.lineKey,
              initialValue: row.tc,
              readOnly: readOnly,
              onChanged: onTcChanged,
            ),
          ),
        ),
        SizedBox(
          height: cellHeight,
          child: _BodyCell(row.unitPrice, align: TextAlign.right),
        ),
        SizedBox(
          height: cellHeight,
          child: _BodyCell(row.lineTotal, align: TextAlign.right),
        ),
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

class _TcInlineField extends StatefulWidget {
  const _TcInlineField({
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
  State<_TcInlineField> createState() => _TcInlineFieldState();
}

class _TcInlineFieldState extends State<_TcInlineField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_TcInlineField oldWidget) {
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
    if (widget.readOnly) {
      return Center(
        child: Text(
          widget.initialValue,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
    }

    return TextField(
      controller: _controller,
      readOnly: widget.readOnly,
      maxLength: 7,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      onChanged: (value) => widget.onChanged(widget.lineKey, value),
      cursorColor: Colors.black,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
      decoration: const InputDecoration(
        isDense: true,
        filled: false,
        fillColor: Colors.transparent,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 1.2),
        ),
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
            cursorColor: Colors.black,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              hintText: 'N° serie',
              hintStyle: TextStyle(color: Colors.black54, fontSize: 10),
              contentPadding: EdgeInsets.only(bottom: 1),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
