import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../widgets/feria_shell.dart';
import '../../services/catalog_service.dart';

class AdminExportScreen extends StatelessWidget {
  const AdminExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final json = context.watch<CatalogService>().exportJson();

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Exportar catálogo'),
        actions: [
          IconButton(
            tooltip: 'Copiar JSON',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppConfig.useSupabase
                ? 'Respaldo del catálogo'
                : 'Subí este JSON a la nube',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            AppConfig.useSupabase
                ? 'Con Supabase activo, los cambios se guardan solos al editar productos. Este JSON sirve como respaldo o para migrar datos.'
                : 'Después de editar productos acá, copiá el JSON y reemplazá el archivo products.json en tu nube.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copiado al portapapeles')),
              );
            },
            child: const Text('COPIAR JSON'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: SelectableText(
              json,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
