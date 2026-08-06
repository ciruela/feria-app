import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/stock_config.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/in_tenant_flow_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/layout_breakpoints.dart';
import '../../widgets/employee/catalog_category_chips.dart';
import '../../widgets/employee/catalog_product_list.dart';
import '../../widgets/employee/employee_cart_panel.dart';
import '../../widgets/employee/employee_nav.dart';
import '../../widgets/employee/employee_role_widgets.dart';
import '../../widgets/section_header.dart';
import '../auth/tenant_app_shell.dart';
import '../cart_screen.dart';

class EmployeeCatalogScreen extends StatefulWidget {
  const EmployeeCatalogScreen({super.key});

  @override
  State<EmployeeCatalogScreen> createState() => _EmployeeCatalogScreenState();
}

class _EmployeeCatalogScreenState extends State<EmployeeCatalogScreen> {
  ProductType? _typeFilter;
  String _searchQuery = '';
  EmployeeNavItem _nav = EmployeeNavItem.catalog;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> _products(CatalogService catalog) {
    final source =
        _typeFilter == null ? catalog.products : catalog.byType(_typeFilter!);
    final query = _searchQuery.trim().toUpperCase();

    final results = source.where((product) {
      if (query.isEmpty) return true;
      if (product.codigo.toUpperCase().contains(query)) return true;
      if (product.modeloDisplay.toUpperCase().contains(query)) return true;
      if (product.calibre.toUpperCase().contains(query)) return true;
      if (product.marca.toUpperCase().contains(query)) return true;
      if (product.descripcion.toUpperCase().contains(query)) return true;
      return false;
    }).toList();

    results.sort((a, b) {
      final byMarca = a.marca.toLowerCase().compareTo(b.marca.toLowerCase());
      if (byMarca != 0) return byMarca;
      if (a.isArma) {
        return a.modeloDisplay.toLowerCase().compareTo(b.modeloDisplay.toLowerCase());
      }
      return a.codigo.compareTo(b.codigo);
    });

    return results;
  }

  int _lowStockCount(List<Product> products) =>
      products.where((p) => isLowStock(p.stock)).length;

  void _handleNav(EmployeeNavItem item) {
    switch (item) {
      case EmployeeNavItem.catalog:
        setState(() => _nav = EmployeeNavItem.catalog);
      case EmployeeNavItem.byCode:
        setState(() => _nav = EmployeeNavItem.byCode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocus.requestFocus();
        });
      case EmployeeNavItem.adminProducts:
      case EmployeeNavItem.adminExchange:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disponible en modo Administración desde el selector de rol.'),
          ),
        );
      case EmployeeNavItem.cart:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CartScreen()),
        );
      case EmployeeNavItem.exit:
        _exit();
    }
  }

  void _exit() {
    final session = context.read<TenantSessionService>();
    if (session.isSellerPortalSession) {
      context.read<AuthService>().logout();
      session.signOut();
    } else {
      exitInTenantFlow(context);
    }
  }

  void _changeSeller() {
    final session = context.read<TenantSessionService>();
    if (session.isSellerPortalSession) {
      session.signOut();
    } else {
      context.read<InTenantFlowService>().openSellerSelect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);
    final catalog = context.watch<CatalogService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final seller = context.watch<SellerService>().selected;
    final cartCount = context.watch<CartService>().itemCount;
    final products = _products(catalog);
    final lowStockCount = _lowStockCount(catalog.products);
    final sellerName = seller != null ? formatSellerFirstName(seller.nombre) : '—';
    final sellerInitial = sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';

    final catalogBody = _CatalogBody(
      products: products,
      totalLoaded: catalog.products.length,
      lowStockCount: lowStockCount,
      searchController: _searchController,
      searchFocus: _searchFocus,
      searchQuery: _searchQuery,
      typeFilter: _typeFilter,
      sellerName: sellerName,
      sellerInitial: sellerInitial,
      exchangeRate: exchangeRate,
      isDesktop: isDesktop,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      onTypeChanged: (type) => setState(() => _typeFilter = type),
      onChangeSeller: _changeSeller,
      onSync: AppConfig.usesRemoteCatalog && !catalog.isSyncing
          ? () => catalog.syncFromCloud()
          : null,
      isSyncing: catalog.isSyncing,
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeSidebar(
              selected: _nav,
              onSelected: _handleNav,
            ),
            Expanded(child: catalogBody),
            const EmployeeCartPanel(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: catalogBody,
      bottomNavigationBar: EmployeeBottomNav(
        selected: _nav,
        cartCount: cartCount,
        onCatalog: () => _handleNav(EmployeeNavItem.catalog),
        onCart: () => _handleNav(EmployeeNavItem.cart),
        onExit: _exit,
      ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.products,
    required this.totalLoaded,
    required this.lowStockCount,
    required this.searchController,
    required this.searchFocus,
    required this.searchQuery,
    required this.typeFilter,
    required this.sellerName,
    required this.sellerInitial,
    required this.exchangeRate,
    required this.isDesktop,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onChangeSeller,
    required this.onSync,
    required this.isSyncing,
  });

  final List<Product> products;
  final int totalLoaded;
  final int lowStockCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final String searchQuery;
  final ProductType? typeFilter;
  final String sellerName;
  final String sellerInitial;
  final ExchangeRateService exchangeRate;
  final bool isDesktop;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductType?> onTypeChanged;
  final VoidCallback onChangeSeller;
  final VoidCallback? onSync;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $sellerName',
                          style: AppText.heading.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Armas cortas · largas · munición',
                          style: AppText.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocus,
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Código, modelo o calibre',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceRaised,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDecorations.radius),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppDecorations.radius),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (onSync != null)
                      IconButton(
                        tooltip: 'Actualizar catálogo',
                        onPressed: isSyncing ? null : onSync,
                        icon: isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                      ),
                    Material(
                      color: AppColors.surfaceTouch,
                      borderRadius: BorderRadius.circular(AppDecorations.radius),
                      child: InkWell(
                        onTap: onChangeSeller,
                        borderRadius: BorderRadius.circular(AppDecorations.radius),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Text(
                              sellerInitial,
                              style: AppText.bodyLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DesktopStatsRow(
                  rate: exchangeRate.hasServerRate ? exchangeRate.rate : null,
                  updatedAt: exchangeRate.updatedAt,
                  lowStockCount: lowStockCount,
                  showing: products.length,
                  totalLoaded: totalLoaded,
                ),
              ],
            ),
          ),
          CatalogCategoryChips(
            selected: typeFilter,
            onSelected: onTypeChanged,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: products.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    subtitle: 'Probá otro código, modelo o categoría',
                  )
                : CatalogProductTable(products: products),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 28 : 20, isDesktop ? 24 : 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $sellerName',
                          style: AppText.heading.copyWith(
                            fontSize: isDesktop ? 28 : 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Armas cortas · largas · munición',
                          style: AppText.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onSync != null)
                    IconButton(
                      tooltip: 'Actualizar catálogo',
                      onPressed: isSyncing ? null : onSync,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                    ),
                  DollarReferenceChip(
                    compact: !isDesktop,
                    rate: exchangeRate.hasServerRate ? exchangeRate.rate : null,
                    updatedAt: exchangeRate.updatedAt,
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.surfaceTouch,
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    child: InkWell(
                      onTap: onChangeSeller,
                      borderRadius: BorderRadius.circular(AppDecorations.radius),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Text(
                            sellerInitial,
                            style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Código, modelo o calibre',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(height: 16),
                _DesktopStatsRow(
                  rate: exchangeRate.hasServerRate ? exchangeRate.rate : null,
                  updatedAt: exchangeRate.updatedAt,
                  lowStockCount: lowStockCount,
                  showing: products.length,
                  totalLoaded: totalLoaded,
                ),
              ],
            ],
          ),
        ),
        CatalogCategoryChips(
          selected: typeFilter,
          onSelected: onTypeChanged,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Catálogo', style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${products.length} producto${products.length == 1 ? '' : 's'}'
                '${lowStockCount > 0 ? ' · $lowStockCount con últimas unidades' : ''}',
                style: AppText.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados',
                  subtitle: 'Probá otro código, modelo o categoría',
                )
              : isDesktop
                  ? CatalogProductTable(products: products)
                  : ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        return CatalogProductRow(product: products[index]);
                      },
                    ),
        ),
      ],
    );
  }
}

class _DesktopStatsRow extends StatelessWidget {
  const _DesktopStatsRow({
    required this.rate,
    required this.updatedAt,
    required this.lowStockCount,
    required this.showing,
    required this.totalLoaded,
  });

  final double? rate;
  final DateTime? updatedAt;
  final int lowStockCount;
  final int showing;
  final int totalLoaded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'DÓLAR DE REFERENCIA',
            value: rate != null ? _formatReferenceRate(rate!) : '—',
            subtitle: updatedAt != null ? formatDateTime(updatedAt!) : null,
            accent: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'ÚLTIMAS UNIDADES',
            value: '$lowStockCount productos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'MOSTRANDO',
            value: '$showing de $totalLoaded cargados',
          ),
        ),
      ],
    );
  }
}

String _formatReferenceRate(double rate) {
  return NumberFormat('#,##0', 'es_AR').format(rate);
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.subtitle,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppText.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.accent : AppColors.textPrimary,
              fontSize: accent ? 22 : 16,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppText.bodySmall),
          ],
        ],
      ),
    );
  }
}
