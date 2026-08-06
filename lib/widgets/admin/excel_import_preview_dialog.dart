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

class _ExcelImportPreviewDialog extends StatelessWidget {
  const _ExcelImportPreviewDialog({required this.preview});

  final ExcelImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final applicable = preview.toCreate + preview.toUpdate;

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
            mainAxisSize: MainAxisSize.min,
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
                  ),
                  _SummaryPill(
                    label: 'Actualizan',
                    value: preview.toUpdate,
                    color: AppColors.primary,
                  ),
                  _SummaryPill(
                    label: 'Se omiten',
                    value: preview.toSkip + preview.unreadable,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: preview.rows.isEmpty
                    ? const Center(
                        child: Text('No se reconoció ninguna fila de producto'),
                      )
                    : _PreviewTable(rows: preview.rows),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCELAR'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
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

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.rows});

  final List<ExcelImportPreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
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
            ],
            rows: rows.map(_buildRow).toList(),
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

    return DataRow(
      cells: [
        DataCell(_ActionBadge(action: item.action)),
        DataCell(Text(row.type.label, style: style)),
        DataCell(Text(_orDash(row.marca), style: style)),
        DataCell(Text(_orDash(row.calibre), style: style)),
        DataCell(Text(_orDash(row.modelo), style: style)),
        DataCell(Text(_orDash(row.codigo), style: style)),
        DataCell(Text(formatUsd(row.precioUsd), style: style)),
        DataCell(Text(row.stock?.toString() ?? '—', style: style)),
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
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
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
    );
  }
}
