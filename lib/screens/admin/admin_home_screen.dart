import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../services/catalog_service.dart';
import '../../services/seller_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/big_action_button.dart';
import '../employee/employee_home_screen.dart';
import '../exchange_rate_screen.dart';
import '../role_gate_screen.dart';
import 'admin_change_pin_screen.dart';
import 'admin_excel_screen.dart';
import 'admin_export_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_products_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Administración'),
            const SizedBox(width: 10),
            roleBadge(AppRole.admin),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Salir',
            iconSize: 30,
            onPressed: () => exitToRoleGate(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Panel de administración',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${catalog.products.length} productos cargados',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (catalog.lastSync != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última sync: ${formatDateTime(catalog.lastSync!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          BigActionButton(
            label: 'Productos y stock',
            subtitle: 'Editar precios, stock y fotos',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminProductsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Tipo de cambio',
            subtitle: 'Actualizar dólar del día',
            icon: Icons.currency_exchange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExchangeRateScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Precios y cuotas',
            subtitle: 'Efectivo, tarjeta 3/6/12 cuotas',
            icon: Icons.payments_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminPricingScreen(),
                ),
              );
            },
          ),
          if (AppConfig.usesRemoteSellers) ...[
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Sincronizar vendedores',
              subtitle: AppConfig.useSupabase
                  ? 'Bajar lista desde Supabase'
                  : 'Bajar lista desde la nube',
              icon: Icons.people_outline,
              onTap: () => context.read<SellerService>().syncFromCloud(),
            ),
          ],
          if (AppConfig.usesRemoteCatalog) ...[
            const SizedBox(height: 16),
            BigActionButton(
              label: AppConfig.useSupabase
                  ? 'Bajar catálogo de Supabase'
                  : 'Bajar catálogo de la nube',
              subtitle: 'Traer última versión publicada',
              icon: Icons.cloud_download_outlined,
              onTap: catalog.isSyncing ? () {} : () => catalog.syncFromCloud(),
            ),
          ],
          if (AppConfig.useSupabase) ...[
            const SizedBox(height: 16),
            BigActionButton(
              label: 'Publicar catálogo a Supabase',
              subtitle: 'Subir todos los productos locales',
              icon: Icons.cloud_upload_outlined,
              onTap: catalog.isSyncing
                  ? () {}
                  : () async {
                      try {
                        await catalog.publishAllToSupabase();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Catálogo publicado en Supabase'),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              catalog.lastError ?? 'Error al publicar',
                            ),
                          ),
                        );
                      }
                    },
            ),
          ],
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Importar / Exportar Excel',
            subtitle: 'Stock, precios, marca, calibre, modelo',
            icon: Icons.table_chart_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminExcelScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Exportar catálogo JSON',
            subtitle: 'Copiar JSON para subir a la nube',
            icon: Icons.upload_file_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminExportScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Ver como empleado',
            subtitle: 'Previsualizar la app del vendedor',
            icon: Icons.visibility_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmployeeHomeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: 'Cambiar PIN admin',
            subtitle: 'PIN por defecto: 2580',
            icon: Icons.lock_outline,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminChangePinScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
