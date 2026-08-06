import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import '../../widgets/employee/catalog_desktop_header.dart';
import '../../widgets/employee/catalog_mobile_layout.dart';
import '../../widgets/employee/catalog_product_list.dart';
import '../../widgets/employee/employee_desktop_shell.dart';
import '../../widgets/employee/employee_nav.dart';
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

    final catalogBody = _CatalogDesktopBody(
      products: products,
      totalLoaded: catalog.products.length,
      lowStockCount: lowStockCount,
      searchController: _searchController,
      searchFocus: _searchFocus,
      typeFilter: _typeFilter,
      sellerName: sellerName,
      sellerInitial: sellerInitial,
      exchangeRate: exchangeRate,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      onTypeChanged: (type) => setState(() => _typeFilter = type),
      onChangeSeller: _changeSeller,
    );

    if (isDesktop) {
      return EmployeeDesktopShell(
        selected: _nav,
        onNav: _handleNav,
        body: catalogBody,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: CatalogMobileLayout(
          products: products,
          totalLoaded: catalog.products.length,
          lowStockCount: lowStockCount,
          searchController: _searchController,
          searchFocus: _searchFocus,
          typeFilter: _typeFilter,
          sellerName: sellerName,
          sellerInitial: sellerInitial,
          exchangeRate: exchangeRate,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onTypeChanged: (type) => setState(() => _typeFilter = type),
          onChangeSeller: _changeSeller,
          onSync: catalogMobileShowSync() && !catalog.isSyncing
              ? () => catalog.syncFromCloud()
              : null,
          isSyncing: catalog.isSyncing,
        ),
      ),
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

class _CatalogDesktopBody extends StatelessWidget {
  const _CatalogDesktopBody({
    required this.products,
    required this.totalLoaded,
    required this.lowStockCount,
    required this.searchController,
    required this.searchFocus,
    required this.typeFilter,
    required this.sellerName,
    required this.sellerInitial,
    required this.exchangeRate,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onChangeSeller,
  });

  final List<Product> products;
  final int totalLoaded;
  final int lowStockCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ProductType? typeFilter;
  final String sellerName;
  final String sellerInitial;
  final ExchangeRateService exchangeRate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductType?> onTypeChanged;
  final VoidCallback onChangeSeller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CatalogDesktopHeader(
          sellerName: sellerName,
          sellerInitial: sellerInitial,
          exchangeRate: exchangeRate,
          lowStockCount: lowStockCount,
          showing: products.length,
          totalLoaded: totalLoaded,
          onChangeSeller: onChangeSeller,
          searchController: searchController,
          searchFocus: searchFocus,
          onSearchChanged: onSearchChanged,
        ),
        CatalogCategoryChips(
          selected: typeFilter,
          onSelected: onTypeChanged,
          desktopHandoff: true,
        ),
        const SizedBox(height: 12),
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
}
