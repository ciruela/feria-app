import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/catalog_service.dart';
import '../../services/tenant_session_service.dart';
import '../../widgets/admin/excel_import_preview_dialog.dart';
import '../../widgets/feria_shell.dart';

class AdminExcelScreen extends StatefulWidget {
  const AdminExcelScreen({super.key});

  @override
  State<AdminExcelScreen> createState() => _AdminExcelScreenState();
}

class _AdminExcelScreenState extends State<AdminExcelScreen> {
  bool _busy = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String _progressPhase = '';

  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      final catalog = context.read<CatalogService>();
      final bytes = catalog.exportToExcel();
      final fileName =
          'catalogo_feria_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel exportado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExcel() async {
    setState(() {
      _busy = true;
      _progressDone = 0;
      _progressTotal = 0;
      _progressPhase = '';
    });
    try {
      final catalog = context.read<CatalogService>();
      final session = context.read<TenantSessionService>();
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (picked == null || picked.files.single.bytes == null) {
        return;
      }

      final bytes = picked.files.single.bytes!;
      final preview = catalog.previewExcel(bytes);
      if (!mounted) return;
      final confirmed = await showExcelImportPreview(context, preview);
      if (!confirmed || !mounted) return;

      await session.ensureSupabaseWriteContext();
      if (!mounted) return;
      final result = await catalog.importFromExcel(
        bytes,
        onProgress: (done, total, phase) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
            _progressPhase = phase;
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importado: ${result.updated} actualizados, '
            '${result.added} nuevos, ${result.skipped} omitidos',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: const FeriaAppBar(
        title: Text('Excel'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Importar / Exportar Excel',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Columnas: tipo, marca, calibre, modelo, codigo, descripcion, '
            'precio_usd, balas_por_caja, stock (cajas). En munición, "calibre" '
            'es opcional. La marca sale del título de la hoja, "Marca: X" o '
            'columna marca (si falta, esa fila se omite). Se leen todas las hojas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Munición: "stock" = cajas. Si en vez de cajas ponés "total_balas" '
            '(balas) junto con "balas_por_caja", la app calcula las cajas sola. '
            'También reconoce encabezados tipo CCI: CAJA X, TOTAL, CAJAS, PRECIO.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Armas: usá modelo. Munición: usá codigo. '
            'Al importar se actualiza stock, precio, descripción y balas por caja.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _exportExcel,
            child: const Text('EXPORTAR EXCEL'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _importExcel,
            child: const Text('IMPORTAR EXCEL'),
          ),
          const SizedBox(height: 24),
          Text(
            'Valores de tipo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text('municion · arma_corta · arma_larga'),
          if (_busy) ...[
            const SizedBox(height: 24),
            _ImportProgress(
              done: _progressDone,
              total: _progressTotal,
              phase: _progressPhase,
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra de progreso de la importación. Muestra la fase y el avance real
/// (determinado) cuando hay total; indeterminada mientras se prepara.
class _ImportProgress extends StatelessWidget {
  const _ImportProgress({
    required this.done,
    required this.total,
    required this.phase,
  });

  final int done;
  final int total;
  final String phase;

  @override
  Widget build(BuildContext context) {
    final hasTotal = total > 0;
    final value = hasTotal ? (done / total).clamp(0.0, 1.0) : null;
    final label = phase.isEmpty ? 'Importando…' : phase;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasTotal)
              Text(
                '$done / $total  (${((value ?? 0) * 100).round()}%)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'No cierres esta pantalla hasta que termine.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
