import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/big_action_button.dart';
import '../../widgets/quick_nav_bar.dart';
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
    final seller = context.watch<SellerService>().selected;
    final cartCount = context.watch<CartService>().itemCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Catálogo Feria'),
            const SizedBox(width: 10),
            roleBadge(AppRole.employee),
          ],
        ),
        actions: [
          if (AppConfig.usesRemoteCatalog)
            IconButton(
              tooltip: 'Actualizar catálogo',
              iconSize: 30,
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
          IconButton(
            tooltip: 'Cambiar vendedor',
            iconSize: 30,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SellerSelectScreen()),
              );
            },
            icon: const Icon(Icons.person_outline),
          ),
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
          if (seller != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0F7A52)),
              ),
              child: Text(
                'Atiende: ${seller.nombre}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F7A52),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipo de cambio hoy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '1 USD = ${formatArs(exchangeRate.rate)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (exchangeRate.updatedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Actualizado: ${formatDateTime(exchangeRate.updatedAt!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (AppConfig.usesRemoteCatalog) ...[
            const SizedBox(height: 16),
            _SyncStatusCard(catalog: catalog),
          ],
          const SizedBox(height: 24),
          Text(
            '¿Qué querés ver?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: ProductType.armaCorta.label,
            subtitle: 'Ver todo con filtros rápidos',
            icon: Icons.shield_outlined,
            onTap: () => _openCatalog(context, ProductType.armaCorta),
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: ProductType.armaLarga.label,
            subtitle: 'Ver todo con filtros rápidos',
            icon: Icons.sports_martial_arts_outlined,
            onTap: () => _openCatalog(context, ProductType.armaLarga),
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: ProductType.municion.label,
            subtitle: 'Ver todo con filtros rápidos',
            icon: Icons.local_fire_department_outlined,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catálogo en la nube',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            catalog.lastSync == null
                ? 'Sin sincronizar todavía'
                : 'Actualizado: ${formatDateTime(catalog.lastSync!)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (catalog.lastError != null) ...[
            const SizedBox(height: 6),
            Text(
              'Usando datos guardados (sin conexión)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
