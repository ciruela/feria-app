import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/stock_config.dart';
import '../../models/product.dart';
import '../../models/product_search_index.dart';
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
import '../../widgets/employee/catalog_filter_bar.dart';
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
  String? _marcaFilter;
  String? _calibreFilter;
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

  /// Catálogo vendible: solo productos con stock > 0 (null/"—" no se muestran).
  ///
  /// Excepción Urban Tactical: los productos con precios fijos se muestran
  /// SIEMPRE (catálogo fiel al Excel), aunque tengan stock 0. La disponibilidad
  /// real la aclara la propia ficha ("consultar disponibilidad").
  List<Product> _availableProducts(CatalogService catalog) => catalog.products
      .where((p) => (p.stock ?? 0) > 0 || p.hasFixedPrices)
      .toList();

  /// Productos disponibles del tipo elegido (sin aplicar marca/calibre/búsqueda).
  List<Product> _typeSource(CatalogService catalog) {
    final available = _availableProducts(catalog);
    if (_typeFilter == null) return available;
    return available.where((p) => p.type == _typeFilter).toList();
  }

  /// Marcas disponibles para el tipo elegido.
  List<String> _marcaOptions(CatalogService catalog) =>
      _distinct(_typeSource(catalog), (p) => p.marca);

  /// Calibres disponibles para el tipo (acotados por la marca elegida).
  List<String> _calibreOptions(CatalogService catalog) {
    final source = _typeSource(catalog).where(
      (p) => _marcaFilter == null || p.marca == _marcaFilter,
    );
    return _distinct(source, (p) => p.calibre);
  }

  List<String> _distinct(
    Iterable<Product> source,
    String Function(Product) selector,
  ) {
    final set = <String>{};
    for (final product in source) {
      final value = selector(product).trim();
      if (value.isNotEmpty) set.add(value);
    }
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void _onTypeChanged(ProductType? type) {
    setState(() {
      _typeFilter = type;
      // Las marcas/calibres dependen del tipo: se limpian para no quedar vacíos.
      _marcaFilter = null;
      _calibreFilter = null;
    });
  }

  void _onMarcaChanged(String? marca) {
    setState(() {
      _marcaFilter = marca;
      // Si el calibre elegido ya no aplica a la marca, se limpia.
      if (_calibreFilter != null &&
          !_calibreOptions(context.read<CatalogService>())
              .contains(_calibreFilter)) {
        _calibreFilter = null;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _marcaFilter = null;
      _calibreFilter = null;
    });
  }

  List<Product> _products(CatalogService catalog) {
    // Filtros de marca/calibre primero; el ordenamiento y la búsqueda por
    // texto los resuelve searchCatalog (que ya cae al orden actual a igual
    // puntaje y devuelve todo ordenado con consulta vacía).
    final source = _typeSource(catalog).where((product) {
      if (_marcaFilter != null && product.marca != _marcaFilter) return false;
      if (_calibreFilter != null && product.calibre != _calibreFilter) {
        return false;
      }
      return true;
    });

    return searchCatalog(source, _searchQuery, catalog.searchIndexFor);
  }

  int _lowStockCount(List<Product> products) =>
      products.where((p) => isLowStock(p.stock)).length;

  void _handleNav(EmployeeNavItem item) {
    switch (item) {
      case EmployeeNavItem.catalog:
        setState(() => _nav = EmployeeNavItem.catalog);
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
    final available = _availableProducts(catalog);
    final products = _products(catalog);
    final lowStockCount = _lowStockCount(available);
    final sellerName = seller != null ? formatSellerFirstName(seller.nombre) : '—';
    final sellerInitial = sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';
    final marcaOptions = _marcaOptions(catalog);
    final calibreOptions = _calibreOptions(catalog);

    final catalogBody = _CatalogDesktopBody(
      products: products,
      totalLoaded: available.length,
      lowStockCount: lowStockCount,
      searchController: _searchController,
      searchFocus: _searchFocus,
      typeFilter: _typeFilter,
      marcaOptions: marcaOptions,
      calibreOptions: calibreOptions,
      marcaFilter: _marcaFilter,
      calibreFilter: _calibreFilter,
      sellerName: sellerName,
      sellerInitial: sellerInitial,
      exchangeRate: exchangeRate,
      onSearchChanged: (value) => setState(() => _searchQuery = value),
      onTypeChanged: _onTypeChanged,
      onMarcaChanged: _onMarcaChanged,
      onCalibreChanged: (value) => setState(() => _calibreFilter = value),
      onClearFilters: _clearFilters,
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
          totalLoaded: available.length,
          lowStockCount: lowStockCount,
          searchController: _searchController,
          searchFocus: _searchFocus,
          typeFilter: _typeFilter,
          marcaOptions: marcaOptions,
          calibreOptions: calibreOptions,
          marcaFilter: _marcaFilter,
          calibreFilter: _calibreFilter,
          sellerName: sellerName,
          sellerInitial: sellerInitial,
          exchangeRate: exchangeRate,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          onTypeChanged: _onTypeChanged,
          onMarcaChanged: _onMarcaChanged,
          onCalibreChanged: (value) => setState(() => _calibreFilter = value),
          onClearFilters: _clearFilters,
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
    required this.marcaOptions,
    required this.calibreOptions,
    required this.marcaFilter,
    required this.calibreFilter,
    required this.sellerName,
    required this.sellerInitial,
    required this.exchangeRate,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onMarcaChanged,
    required this.onCalibreChanged,
    required this.onClearFilters,
    required this.onChangeSeller,
  });

  final List<Product> products;
  final int totalLoaded;
  final int lowStockCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ProductType? typeFilter;
  final List<String> marcaOptions;
  final List<String> calibreOptions;
  final String? marcaFilter;
  final String? calibreFilter;
  final String sellerName;
  final String sellerInitial;
  final ExchangeRateService exchangeRate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductType?> onTypeChanged;
  final ValueChanged<String?> onMarcaChanged;
  final ValueChanged<String?> onCalibreChanged;
  final VoidCallback onClearFilters;
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
        const SizedBox(height: 10),
        CatalogFilterBar(
          marcas: marcaOptions,
          calibres: calibreOptions,
          selectedMarca: marcaFilter,
          selectedCalibre: calibreFilter,
          onMarcaChanged: onMarcaChanged,
          onCalibreChanged: onCalibreChanged,
          onClear: onClearFilters,
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
