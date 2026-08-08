import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/presupuesto_document.dart';
import '../../utils/presupuesto_row_heights.dart';
import '../../utils/uppercase_input.dart';

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
    // AR-59: alturas fit-to-page para no clippear checks/firma debajo del total.
    final heights = PresupuestoRowHeights.resolve(
      rows: rows,
      bodyHeight: bodyHeight,
      headerHeight: PresupuestoItemsTable._headerHeight,
      armaPref: 54,
      normalPref: branding.isUrban ? 28 : 22,
      fillerPref: 22,
    );

    // Marca de agua Urban: página completa en PresupuestoUrbanPaper.
    return Table(
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
          if (row.isEmpty) {
            return TableRow(
              children: List.generate(
                3,
                (_) => SizedBox(
                  height: heights.filler,
                  child: const _BodyCell(''),
                ),
              ),
            );
          }

          final cellHeight = heights.forRow(row);

          return TableRow(
            children: [
              SizedBox(
                height: cellHeight,
                child: ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          row.detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (row.isArma) ...[
                          const SizedBox(height: 2),
                          _SerialInlineField(
                            key: ValueKey('serial-${row.lineKey}'),
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
    final heights = PresupuestoRowHeights.resolve(
      rows: rows,
      bodyHeight: bodyHeight,
      headerHeight: PresupuestoItemsTable._headerHeight,
      armaPref: 52,
      normalPref: 22,
      fillerPref: 22,
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
        ...rows.map((row) => _buildRow(row, heights)),
      ],
    );
  }

  TableRow _buildRow(PresupuestoItemRow row, PresupuestoRowHeights heights) {
    if (row.isEmpty) {
      return TableRow(
        children: List.generate(
          6,
          (_) => SizedBox(height: heights.filler, child: const _BodyCell('')),
        ),
      );
    }

    final cellHeight = heights.forRow(row);
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (row.isArma) ...[
                  const SizedBox(height: 4),
                  _SerialInlineField(
                    key: ValueKey('serial-${row.lineKey}'),
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
              key: ValueKey('tc-${row.lineKey}'),
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
    super.key,
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
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
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
    super.key,
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
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_SerialInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No pisar mientras el usuario escribe (evita perder cursor en A4 scaled).
    if (!_focusNode.hasFocus &&
        widget.initialValue != _controller.text &&
        widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'SERIE:',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          // AR-51: disabled TextField painted black bands on comprobante.
          child: widget.readOnly
              ? Container(
                  padding: const EdgeInsets.only(bottom: 1),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black),
                    ),
                  ),
                  child: Text(
                    _controller.text.trim().isEmpty
                        ? ' '
                        : _controller.text,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                )
              : TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: UpperCaseTextFormatter.formatters,
                  onChanged: (value) =>
                      widget.onChanged(widget.lineKey, value),
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
