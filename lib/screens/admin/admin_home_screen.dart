import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../services/catalog_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/big_action_button.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import '../employee/employee_home_screen.dart';
import '../exchange_rate_screen.dart';
import '../role_gate_screen.dart';
import 'admin_change_pin_screen.dart';
import 'admin_excel_screen.dart';
import 'admin_export_screen.dart';
import 'admin_metrics_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_products_screen.dart';
import 'admin_sellers_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final sellers = context.watch<SellerService>();

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const FeriaAppBarTitle('Administración'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: () => exitToRoleGate(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: roleBadge(AppRole.admin),
          ),
          const SizedBox(height: 12),
          StatCard(
            icon: Icons.inventory_2_rounded,
            label: 'Catálogo cargado',
            value: '${catalog.products.length} productos',
            subtitle: catalog.lastSync == null
                ? 'Sin sincronizar con la nube'
                : 'Última sync: ${formatDateTime(catalog.lastSync!)}',
            accentColor: AppColors.goldDark,
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Panel de administración',
            subtitle: 'Gestioná precios, stock y configuración',
          ),
          const SizedBox(height: 18),
          BigActionButton(
            label: 'Productos y stock',
            subtitle: 'Crear, editar, importar y exportar',
            icon: Icons.inventory_2_outlined,
            accentColor: AppColors.primary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminProductsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Tipo de cambio',
            subtitle: 'Actualizar dólar del día',
            icon: Icons.currency_exchange_rounded,
            accentColor: AppColors.goldDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExchangeRateScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Precios y cuotas',
            subtitle: 'Débito y cuotas 1/3/6/9/12/18',
            icon: Icons.payments_rounded,
            accentColor: AppColors.accent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminPricingScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Vendedores',
            subtitle: sellers.lastError != null
                ? 'Error de sync — tocá para gestionar'
                : '${sellers.activeCount} activos · agregar o desactivar',
            icon: Icons.groups_rounded,
            accentColor: sellers.lastError != null
                ? AppColors.danger
                : AppColors.armaCorta,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminSellersScreen(),
                ),
              );
            },
          ),
          if (AppConfig.usesRemoteSellers && !AppConfig.useSupabase) ...[
            const SizedBox(height: 14),
            BigActionButton(
              label: 'Sincronizar vendedores',
              subtitle: 'Bajar lista desde la nube',
              icon: Icons.cloud_download_outlined,
              accentColor: AppColors.armaCorta,
              onTap: sellers.isSyncing
                  ? () {}
                  : () async {
                      await context.read<SellerService>().syncFromCloud();
                      if (!context.mounted) return;
                      final error = context.read<SellerService>().lastError;
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                      }
                    },
            ),
          ],
          if (AppConfig.usesRemoteCatalog) ...[
            const SizedBox(height: 14),
            BigActionButton(
              label: AppConfig.useSupabase
                  ? 'Bajar catálogo de Supabase'
                  : 'Bajar catálogo de la nube',
              subtitle: 'Traer última versión publicada',
              icon: Icons.cloud_download_outlined,
              accentColor: AppColors.armaCorta,
              onTap: catalog.isSyncing ? () {} : () => catalog.syncFromCloud(),
            ),
          ],
          if (AppConfig.useSupabase) ...[
            const SizedBox(height: 14),
            BigActionButton(
              label: 'Publicar catálogo a Supabase',
              subtitle: 'Subir todos los productos locales',
              icon: Icons.cloud_upload_outlined,
              accentColor: AppColors.municion,
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
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Métricas del día',
            subtitle: AppConfig.useSupabase
                ? 'Ventas, categorías, pagos y vendedores'
                : 'Requiere Supabase configurado',
            icon: Icons.insights_rounded,
            accentColor: AppColors.success,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminMetricsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Importar / Exportar Excel',
            subtitle: 'Stock, precios, marca, calibre, modelo',
            icon: Icons.table_chart_outlined,
            accentColor: AppColors.armaLarga,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminExcelScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Exportar catálogo JSON',
            subtitle: 'Copiar JSON para respaldo',
            icon: Icons.upload_file_outlined,
            accentColor: AppColors.primaryLight,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminExportScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Ver como empleado',
            subtitle: 'Previsualizar la app del vendedor',
            icon: Icons.visibility_outlined,
            accentColor: AppColors.accent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmployeeHomeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Cambiar PIN admin',
            subtitle: 'PIN por defecto: 2580',
            icon: Icons.lock_outline,
            accentColor: AppColors.goldDark,
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
