import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/big_action_button.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/quick_nav_bar.dart';
import '../../widgets/section_header.dart';
import '../cart_screen.dart';
import '../category_catalog_screen.dart';
import '../role_gate_screen.dart';
import '../seller_select_screen.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final catalog = context.watch<CatalogService>();
    final sellerService = context.watch<SellerService>();
    final seller = sellerService.selected;
    final cartCount = context.watch<CartService>().itemCount;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const FeriaAppBarTitle('Catálogo Feria'),
        actions: [
          if (AppConfig.usesRemoteCatalog)
            IconButton(
              tooltip: 'Actualizar catálogo',
              onPressed:
                  catalog.isSyncing ? null : () => catalog.syncFromCloud(),
              icon: catalog.isSyncing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_download_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'seller':
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const SellerSelectScreen(),
                    ),
                  );
                case 'logout':
                  exitToRoleGate(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'seller',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Cambiar vendedor'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Salir'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: roleBadge(AppRole.employee),
          ),
          const SizedBox(height: 12),
          if (seller != null) ...[
            InfoBanner(
              text: 'Atiende: ${seller.nombre}',
              icon: Icons.support_agent_rounded,
            ),
            const SizedBox(height: 16),
          ],
          StatCard(
            icon: Icons.currency_exchange_rounded,
            label: 'Tipo de cambio hoy',
            value: '1 USD = ${formatArs(exchangeRate.rate)}',
            subtitle: exchangeRate.updatedAt == null
                ? null
                : 'Actualizado: ${formatDateTime(exchangeRate.updatedAt!)}',
            accentColor: AppColors.goldDark,
          ),
          if (AppConfig.usesRemoteCatalog) ...[
            const SizedBox(height: 16),
            _SyncStatusCard(catalog: catalog),
          ],
          if (AppConfig.usesRemoteSellers) ...[
            const SizedBox(height: 16),
            _SellerSyncStatusCard(seller: sellerService),
          ],
          const SizedBox(height: 28),
          const SectionHeader(
            title: '¿Qué querés ver?',
            subtitle: 'Elegí una categoría para filtrar rápido',
          ),
          const SizedBox(height: 18),
          BigActionButton(
            label: ProductType.armaCorta.label,
            subtitle: 'Pistolas y revólveres',
            icon: Icons.shield_rounded,
            accentColor: AppColors.armaCorta,
            onTap: () => _openCatalog(context, ProductType.armaCorta),
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: ProductType.armaLarga.label,
            subtitle: 'Rifles y escopetas',
            icon: Icons.sports_martial_arts_rounded,
            accentColor: AppColors.armaLarga,
            onTap: () => _openCatalog(context, ProductType.armaLarga),
          ),
          const SizedBox(height: 14),
          BigActionButton(
            label: ProductType.municion.label,
            subtitle: 'Filtrar por código y calibre',
            icon: Icons.local_fire_department_rounded,
            accentColor: AppColors.municion,
            onTap: () => _openCatalog(context, ProductType.municion),
          ),
        ],
      ),
      bottomNavigationBar: QuickNavBar(
        cartCount: cartCount,
        onCartTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
      ),
    );
  }

  void _openCatalog(BuildContext context, ProductType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryCatalogScreen(type: type),
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.catalog});

  final CatalogService catalog;

  @override
  Widget build(BuildContext context) {
    final hasError = catalog.lastError != null;

    return StatCard(
      icon: hasError ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
      label: 'Catálogo en la nube',
      value: catalog.lastSync == null
          ? 'Sin sincronizar'
          : formatDateTime(catalog.lastSync!),
      subtitle: hasError ? 'Usando datos guardados sin conexión' : null,
      accentColor: hasError ? AppColors.danger : AppColors.accent,
    );
  }
}

class _SellerSyncStatusCard extends StatelessWidget {
  const _SellerSyncStatusCard({required this.seller});

  final SellerService seller;

  @override
  Widget build(BuildContext context) {
    final hasError = seller.lastError != null;

    return StatCard(
      icon: hasError ? Icons.cloud_off_rounded : Icons.people_alt_rounded,
      label: 'Vendedores en la nube',
      value: hasError ? 'Error al sincronizar' : '${seller.sellers.length} activos',
      subtitle: hasError ? 'Usando lista guardada sin conexión' : null,
      accentColor: hasError ? AppColors.danger : AppColors.armaCorta,
    );
  }
}
