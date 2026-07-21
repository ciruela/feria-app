import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/catalog_service.dart';

class AdminExcelScreen extends StatefulWidget {
  const AdminExcelScreen({super.key});

  @override
  State<AdminExcelScreen> createState() => _AdminExcelScreenState();
}

class _AdminExcelScreenState extends State<AdminExcelScreen> {
  bool _busy = false;

  Future<void> _exportExcel() async {
    setState(() => _busy = true);
    try {
      final catalog = context.read<CatalogService>();
      final bytes = catalog.exportToExcel();
      final fileName =
          'catalogo_feria_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      await FilePicker.platform.saveFile(
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
    setState(() => _busy = true);
    try {
      final catalog = context.read<CatalogService>();
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (picked == null || picked.files.single.bytes == null) {
        return;
      }

      final result = await catalog.importFromExcel(
        picked.files.single.bytes!,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Excel'),
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
            'Columnas: tipo, marca, calibre, modelo, codigo, precio_usd, stock',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Armas: usá modelo. Munición: usá codigo. '
            'Al importar se actualiza stock y precio.',
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
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
