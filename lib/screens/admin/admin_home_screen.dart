import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../models/sales_metrics.dart';
import '../../services/catalog_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../services/seller_service.dart';
import '../../services/stock_cierre_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/formatters.dart';
import '../../widgets/big_action_button.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import '../../widgets/supabase_config_banner.dart';
import '../../widgets/tenant_app_title.dart';
import '../employee/employee_home_screen.dart';
import '../exchange_rate_screen.dart';
import '../auth/tenant_app_shell.dart';
import '../role_gate_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_admins_screen.dart';
import 'admin_change_pin_screen.dart';
import 'admin_cierre_screen.dart';
import 'admin_comprobantes_screen.dart';
import 'admin_excel_screen.dart';
import 'admin_export_screen.dart';
import 'admin_metrics_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_products_screen.dart';
import 'admin_sellers_screen.dart';
import 'admin_stock_movimientos_screen.dart';
import 'admin_team_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final sellers = context.watch<SellerService>();

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const TenantAppTitle(),
        actions: [
          IconButton(
            tooltip: 'Salir',
            onPressed: () => exitInTenantFlow(context),
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
          const SupabaseConfigBanner(),
          if (AppConfig.useSupabase) ...[
            const _TodayDashboard(),
            const SizedBox(height: 16),
          ],
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
            label: 'Cierre de día',
            subtitle: AppConfig.useSupabase
                ? 'Apertura, vendido y cierre de stock'
                : 'Requiere Supabase configurado',
            icon: Icons.event_available_rounded,
            accentColor: AppColors.armaCorta,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminCierreScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Movimientos de stock',
            subtitle: AppConfig.useSupabase
                ? 'Auditoría: cargas, ventas y ajustes'
                : 'Requiere Supabase configurado',
            icon: Icons.swap_vert_rounded,
            accentColor: AppColors.municion,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminStockMovimientosScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Registro de actividad',
            subtitle: AppConfig.useSupabase
                ? 'Auditoría de acciones de administradores'
                : 'Requiere Supabase configurado',
            icon: Icons.fact_check_rounded,
            accentColor: AppColors.goldDark,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminActivityScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Equipo de la armería',
            subtitle: AppConfig.useSupabase
                ? 'Invitar personas por email a tu organización'
                : 'Requiere Supabase configurado',
            icon: Icons.groups_3_rounded,
            accentColor: AppColors.primaryLight,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminTeamScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: 'Administradores',
            subtitle: 'PIN local para identificar quién opera en el panel',
            icon: Icons.admin_panel_settings_rounded,
            accentColor: AppColors.gold,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminAdminsScreen(),
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

class _TodayDashboard extends StatefulWidget {
  const _TodayDashboard();

  @override
  State<_TodayDashboard> createState() => _TodayDashboardState();
}

class _TodayDashboardState extends State<_TodayDashboard> {
  final _metricsService = SalesMetricsService();
  final _cierreService = StockCierreService();

  DaySalesMetrics? _metrics;
  int _balasVendidas = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final today = DateTime.now();
    final products = context.read<CatalogService>().products;
    try {
      final metrics = await _metricsService.metricsForDay(today);
      var balas = 0;
      try {
        final cierre = await _cierreService.cierreForDay(today, products);
        balas = cierre.totalBalasVendidas;
      } catch (e, s) {
        AppLogger.warn('No se pudo calcular balas vendidas del día',
            error: e, stackTrace: s);
      }
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _balasVendidas = balas;
        _loading = false;
      });
    } catch (e, s) {
      AppLogger.error('No se pudieron cargar las métricas del panel',
          error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _lowStockCount {
    final products = context.read<CatalogService>().products;
    return products
        .where((p) => p.stock != null && p.stock! <= kLowStockThreshold)
        .length;
  }

  void _go(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppDecorations.cardGradient,
        borderRadius: AppDecorations.radiusLg,
        boxShadow: [AppDecorations.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'HOY · ${formatDate(DateTime.now())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _loading ? null : _load,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _DashTile(
                label: 'Ventas',
                value: '${metrics?.saleCount ?? 0}',
                icon: Icons.receipt_long_rounded,
                onTap: () => _go(const AdminComprobantesScreen()),
              ),
              const SizedBox(width: 10),
              _DashTile(
                label: 'Cobrado',
                value: metrics == null ? '—' : formatArs(metrics.totalArs),
                icon: Icons.payments_rounded,
                onTap: () => _go(const AdminMetricsScreen()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DashTile(
                label: 'Balas vendidas',
                value: '$_balasVendidas',
                icon: Icons.adjust_rounded,
                onTap: () => _go(const AdminCierreScreen()),
              ),
              const SizedBox(width: 10),
              _DashTile(
                label: 'Stock bajo',
                value: '$_lowStockCount',
                icon: Icons.warning_amber_rounded,
                highlight: _lowStockCount > 0,
                onTap: () =>
                    _go(const AdminProductsScreen(lowStockOnly: true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  const _DashTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlight
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.15),
                width: highlight ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon,
                        color: highlight ? AppColors.gold : Colors.white70,
                        size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: highlight ? AppColors.gold : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
