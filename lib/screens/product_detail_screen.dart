import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../config/stock_config.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/in_tenant_flow_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/product_photo_service.dart';
import '../services/seller_service.dart';
import '../services/tenant_session_service.dart';
import '../utils/formatters.dart';
import '../theme/app_theme.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/add_to_cart_sheet.dart';
import '../widgets/added_to_cart_sheet.dart';
import '../widgets/employee/employee_desktop_shell.dart';
import '../widgets/employee/employee_nav.dart';
import '../widgets/employee/product_detail_desktop.dart';
import '../widgets/employee/product_detail_mobile.dart';
import 'auth/tenant_app_shell.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _pageController;
  int _page = 0;

  Product get product => widget.product;

  List<String> get _displayUrls =>
      ProductPhotoService.displayUrls(product.fotoUrls);

  Color get _accent {
    switch (product.type) {
      case ProductType.armaCorta:
        return AppColors.armaCorta;
      case ProductType.armaLarga:
        return AppColors.armaLarga;
      case ProductType.municion:
        return AppColors.municion;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen(int initialIndex) {
    if (_displayUrls.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPhotoGallery(
          urls: _displayUrls,
          initialIndex: initialIndex,
          title: product.isArma ? product.modeloDisplay : product.codigo,
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final action = await promptAddToCart(context, product);
    if (!mounted) return;
    await handleAddedToCartNavigation(context, action);
  }

  void _changeSeller() {
    final session = context.read<TenantSessionService>();
    if (session.isSellerPortalSession) {
      session.signOut();
    } else {
      context.read<InTenantFlowService>().openSellerSelect();
    }
  }

  void _handleDesktopNav(BuildContext context, EmployeeNavItem item) {
    switch (item) {
      case EmployeeNavItem.catalog:
      case EmployeeNavItem.byCode:
        Navigator.of(context).pop();
      case EmployeeNavItem.adminProducts:
      case EmployeeNavItem.adminExchange:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disponible en modo Administración desde el selector de rol.'),
          ),
        );
      case EmployeeNavItem.cart:
      case EmployeeNavItem.exit:
        Navigator.of(context).pop();
        if (item == EmployeeNavItem.exit) {
          exitInTenantFlow(context);
        }
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

  void _handleMobileNav(EmployeeNavItem item) {
    switch (item) {
      case EmployeeNavItem.catalog:
      case EmployeeNavItem.byCode:
        Navigator.of(context).pop();
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
        Navigator.of(context).pop();
        _exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final cart = context.watch<CartService>();
    final catalog = context.watch<CatalogService>();
    final seller = context.watch<SellerService>().selected;
    final canAdd = cart.canAddMore(product);
    final sellerName = seller != null ? formatSellerFirstName(seller.nombre) : '—';
    final sellerInitial = sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?';
    final lowStockCount =
        catalog.products.where((p) => isLowStock(p.stock)).length;
    final totalLoaded = catalog.products.length;
    final prices = context.read<PricingService>().pricesFor(
      product,
      exchangeRate,
      pricingSettings,
    );
    final displayUrls = _displayUrls;
    final isDesktop = LayoutBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);

    final gallery = _PhotoGallery(
      foto: product.foto,
      displayUrls: displayUrls,
      marca: product.marca,
      accent: _accent,
      pageController: _pageController,
      page: _page,
      onPageChanged: (index) => setState(() => _page = index),
      onTap: displayUrls.isNotEmpty ? () => _openFullscreen(_page) : null,
      edgeToEdge: !isDesktop,
    );

    if (isDesktop) {
      return EmployeeDesktopShell(
        selected: EmployeeNavItem.catalog,
        onNav: (item) => _handleDesktopNav(context, item),
        body: ProductDetailDesktopLayout(
          product: product,
          prices: prices,
          exchangeRate: exchangeRate,
          showArs: exchangeRate.hasServerRate,
          photoGallery: AspectRatio(aspectRatio: 4 / 3, child: gallery),
          canAdd: canAdd,
          sellerName: sellerName,
          sellerInitial: sellerInitial,
          lowStockCount: lowStockCount,
          totalLoaded: totalLoaded,
          onBack: () => Navigator.of(context).pop(),
          onAddToCart: _addToCart,
          onChangeSeller: _changeSeller,
        ),
      );
    }

    final cartCount = cart.itemCount;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ProductDetailMobileLayout(
        product: product,
        prices: prices,
        showArs: exchangeRate.hasServerRate,
        photoGallery: gallery,
        canAdd: canAdd,
        onBack: () => Navigator.of(context).pop(),
        onAddToCart: _addToCart,
      ),
      bottomNavigationBar: EmployeeBottomNav(
        selected: EmployeeNavItem.catalog,
        cartCount: cartCount,
        onCatalog: () => _handleMobileNav(EmployeeNavItem.catalog),
        onCart: () => _handleMobileNav(EmployeeNavItem.cart),
        onExit: () => _handleMobileNav(EmployeeNavItem.exit),
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({
    required this.foto,
    required this.displayUrls,
    required this.marca,
    required this.accent,
    required this.pageController,
    required this.page,
    required this.onPageChanged,
    this.onTap,
    this.edgeToEdge = false,
  });

  final String foto;
  final List<String> displayUrls;
  final String marca;
  final Color accent;
  final PageController pageController;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onTap;
  final bool edgeToEdge;

  @override
  Widget build(BuildContext context) {
    final image = GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: edgeToEdge ? 1.1 : 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            if (displayUrls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(displayUrls.length, (index) {
                    final active = index == page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            if (onTap != null && !edgeToEdge)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'AMPLIAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (edgeToEdge) return image;

    return ClipRRect(
      borderRadius: AppDecorations.radiusMd,
      child: image,
    );
  }

  Widget _buildImage() {
    if (displayUrls.isNotEmpty) {
      if (displayUrls.length == 1) {
        return _networkImage(displayUrls.first);
      }

      return PageView.builder(
        controller: pageController,
        itemCount: displayUrls.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, index) => _networkImage(displayUrls[index]),
      );
    }

    if (foto.isNotEmpty) {
      return Image.asset(
        foto,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Placeholder(marca: marca, accent: accent),
      );
    }

    return _Placeholder(marca: marca, accent: accent);
  }

  Widget _networkImage(String url) {
    return Container(
      color: accent.withValues(alpha: 0.05),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (_, __) => _Placeholder(marca: marca, accent: accent, loading: true),
        errorWidget: (_, __, ___) => _Placeholder(marca: marca, accent: accent),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.marca,
    required this.accent,
    this.loading = false,
  });

  final String marca;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const CircularProgressIndicator(color: AppColors.primary)
            else
              Icon(
                Icons.photo_camera_back_outlined,
                size: 56,
                color: accent.withValues(alpha: 0.45),
              ),
            const SizedBox(height: 12),
            Text(
              marca.toUpperCase(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.55),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenPhotoGallery extends StatefulWidget {
  const _FullscreenPhotoGallery({
    required this.urls,
    required this.initialIndex,
    required this.title,
  });

  final List<String> urls;
  final int initialIndex;
  final String title;

  @override
  State<_FullscreenPhotoGallery> createState() => _FullscreenPhotoGalleryState();
}

class _FullscreenPhotoGalleryState extends State<_FullscreenPhotoGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.urls.length > 1
              ? '${widget.title} (${_index + 1}/${widget.urls.length})'
              : widget.title,
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
