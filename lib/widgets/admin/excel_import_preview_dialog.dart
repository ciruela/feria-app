import 'package:flutter/material.dart';

import '../../services/excel_catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Muestra los datos interpretados del Excel (marca, calibre, modelo, código,
/// precio, stock) para que el admin los revise antes de confirmar la carga.
/// Devuelve `true` si el admin confirma la importación.
Future<bool> showExcelImportPreview(
  BuildContext context,
  ExcelImportPreview preview,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _ExcelImportPreviewDialog(preview: preview),
  );
  return confirmed ?? false;
}

/// Categorías por las que se puede filtrar la tabla del preview.
enum _PreviewFilter { nuevos, actualizan, omiten, avisos }

class _ExcelImportPreviewDialog extends StatefulWidget {
  const _ExcelImportPreviewDialog({required this.preview});

  final ExcelImportPreview preview;

  @override
  State<_ExcelImportPreviewDialog> createState() =>
      _ExcelImportPreviewDialogState();
}

class _ExcelImportPreviewDialogState extends State<_ExcelImportPreviewDialog> {
  // null = mostrar todo. Al tocar una pill se filtra la tabla.
  _PreviewFilter? _filter;

  ExcelImportPreview get preview => widget.preview;

  bool _matches(ExcelImportPreviewRow row, _PreviewFilter filter) {
    switch (filter) {
      case _PreviewFilter.nuevos:
        return row.action == ExcelImportAction.create;
      case _PreviewFilter.actualizan:
        return row.action == ExcelImportAction.update;
      case _PreviewFilter.omiten:
        return row.action == ExcelImportAction.skip;
      case _PreviewFilter.avisos:
        return row.warnings.isNotEmpty;
    }
  }

  List<ExcelImportPreviewRow> get _visibleRows {
    final f = _filter;
    if (f == null) return preview.rows;
    return preview.rows.where((r) => _matches(r, f)).toList();
  }

  void _toggle(_PreviewFilter filter) {
    setState(() => _filter = _filter == filter ? null : filter);
  }

  String get _hint {
    switch (_filter) {
      case null:
        return 'Tocá una categoría para filtrar. Los avisos no impiden importar.';
      case _PreviewFilter.nuevos:
        return 'Productos que se crean: no existían en la base (por código).';
      case _PreviewFilter.actualizan:
        return 'Ya existen por código: se actualiza stock, precio y descripción.';
      case _PreviewFilter.omiten:
        return 'No se importan: les falta un dato obligatorio (normalmente la marca).';
      case _PreviewFilter.avisos:
        return 'Se importan igual, pero conviene revisar (mirá la columna “Avisos”): '
            '“Precio USD 0” = va en pesos (Bersa/3DURBAN), código repetido, etc.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final applicable = preview.toCreate + preview.toUpdate;
    final visible = _visibleRows;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Revisá antes de importar',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryPill(
                    label: 'Nuevos',
                    value: preview.toCreate,
                    color: AppColors.success,
                    selected: _filter == _PreviewFilter.nuevos,
                    onTap: () => _toggle(_PreviewFilter.nuevos),
                  ),
                  _SummaryPill(
                    label: 'Actualizan',
                    value: preview.toUpdate,
                    color: AppColors.primary,
                    selected: _filter == _PreviewFilter.actualizan,
                    onTap: () => _toggle(_PreviewFilter.actualizan),
                  ),
                  _SummaryPill(
                    label: 'Se omiten',
                    value: preview.toSkip + preview.unreadable,
                    color: AppColors.textSecondary,
                    selected: _filter == _PreviewFilter.omiten,
                    onTap: () => _toggle(_PreviewFilter.omiten),
                  ),
                  if (preview.withWarnings > 0)
                    _SummaryPill(
                      label: 'Con avisos',
                      value: preview.withWarnings,
                      color: AppColors.accent,
                      selected: _filter == _PreviewFilter.avisos,
                      onTap: () => _toggle(_PreviewFilter.avisos),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _hint,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (_filter != null)
                    TextButton(
                      onPressed: () => setState(() => _filter = null),
                      child: const Text('Ver todo'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: preview.rows.isEmpty
                    ? const Center(
                        child: Text('No se reconoció ninguna fila de producto'),
                      )
                    : visible.isEmpty
                        ? const Center(
                            child: Text('No hay filas en esta categoría'),
                          )
                        : _PreviewTable(rows: visible),
              ),
              const SizedBox(height: 16),
              // El tema usa minimumSize: Size.fromHeight (ancho infinito). En un
              // Row eso desborda y oculta IMPORTAR; acá forzamos ancho intrínseco.
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCELAR'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, AppDecorations.buttonPrimary),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: applicable == 0
                        ? null
                        : () => Navigator.of(context).pop(true),
                    child: Text('IMPORTAR ($applicable)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTable extends StatefulWidget {
  const _PreviewTable({required this.rows});

  final List<ExcelImportPreviewRow> rows;

  @override
  State<_PreviewTable> createState() => _PreviewTableState();
}

class _PreviewTableState extends State<_PreviewTable> {
  // Controllers explícitos: sin esto el Scrollbar toma el PrimaryScrollController
  // (que no tiene posición adjunta en web) -> excepción y scroll que no anda.
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _vController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vController,
        child: Scrollbar(
          controller: _hController,
          thumbVisibility: true,
          notificationPredicate: (notification) => notification.depth == 1,
          child: SingleChildScrollView(
            controller: _hController,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceTouch,
              ),
              columns: const [
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Tipo')),
                DataColumn(label: Text('Marca')),
                DataColumn(label: Text('Calibre')),
                DataColumn(label: Text('Modelo')),
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Precio USD')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Avisos')),
              ],
              rows: widget.rows.map(_buildRow).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(ExcelImportPreviewRow item) {
    final row = item.row;
    final dim = item.action == ExcelImportAction.skip;
    final style = dim
        ? const TextStyle(color: AppColors.textSecondary)
        : const TextStyle(color: AppColors.textPrimary);
    final stockLabel = item.existingStock != null && row.stock != null
        ? '${item.existingStock} → ${row.stock}'
        : (row.stock?.toString() ?? '—');

    return DataRow(
      cells: [
        DataCell(_ActionBadge(action: item.action)),
        DataCell(Text(row.type.label, style: style)),
        DataCell(Text(_orDash(row.marca), style: style)),
        DataCell(Text(_orDash(row.calibre), style: style)),
        DataCell(Text(_orDash(row.modelo), style: style)),
        DataCell(Text(_orDash(row.codigo), style: style)),
        DataCell(Text(formatUsd(row.precioUsd), style: style)),
        DataCell(Text(stockLabel, style: style)),
        DataCell(
          Text(
            item.warnings.isEmpty ? '—' : item.warnings.join(' · '),
            style: TextStyle(
              color: item.warnings.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.accent,
              fontSize: 12,
              fontWeight:
                  item.warnings.isEmpty ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action});

  final ExcelImportAction action;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (action) {
      ExcelImportAction.create => ('NUEVO', AppColors.success),
      ExcelImportAction.update => ('ACTUALIZA', AppColors.primary),
      ExcelImportAction.skip => ('OMITE', AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && value > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.22 : 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.0),
              width: 1.5,
            ),
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              children: [
                TextSpan(
                  text: '$value ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(text: label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
