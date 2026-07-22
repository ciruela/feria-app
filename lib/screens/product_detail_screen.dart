import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/product_photo_service.dart';
import '../theme/app_theme.dart';
import '../widgets/added_to_cart_sheet.dart';
import '../widgets/feria_shell.dart';
import '../widgets/payment_method_dialog.dart';
import '../widgets/product_prices_panel.dart';

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
    final cart = context.read<CartService>();
    if (!cart.canAddMore(product)) {
      showStockLimitMessage(context, product);
      return;
    }

    if (product.isArma) {
      final selection = await showWeaponPaymentDialog(
        context,
        product: product,
      );
      if (selection == null || !mounted) return;

      final result = cart.addWeaponPayment(product, selection);
      if (!mounted) return;

      if (result == CartAddResult.stockLimitReached) {
        showStockLimitMessage(context, product);
        return;
      }

      final label = product.modeloDisplay;
      final action = await showAddedToCartSheet(
        context,
        productLabel: label,
      );
      if (!mounted) return;
      await handleAddedToCartNavigation(context, action);
      return;
    }

    final method = await showSinglePaymentDialog(
      context,
      product: product,
    );
    if (method == null || !mounted) return;

    final result = cart.addProduct(product, paymentMethod: method);
    if (!mounted) return;

    if (result == CartAddResult.stockLimitReached) {
      showStockLimitMessage(context, product);
      return;
    }

    final action = await showAddedToCartSheet(
      context,
      productLabel: product.codigo,
    );
    if (!mounted) return;
    await handleAddedToCartNavigation(context, action);
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final cart = context.watch<CartService>();
    final canAdd = cart.canAddMore(product);
    final prices = PricingService().pricesFor(
      product,
      exchangeRate,
      pricingSettings,
    );
    final displayUrls = _displayUrls;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: Text(product.isArma ? product.modeloDisplay : product.codigo),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _DetailHeader(product: product, accent: _accent),
          const SizedBox(height: 16),
          _PhotoGallery(
            foto: product.foto,
            displayUrls: displayUrls,
            marca: product.marca,
            accent: _accent,
            pageController: _pageController,
            page: _page,
            onPageChanged: (index) => setState(() => _page = index),
            onTap: displayUrls.isNotEmpty ? () => _openFullscreen(_page) : null,
          ),
          if (displayUrls.length > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Deslizá para ver ${displayUrls.length} fotos · tocá para ampliar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
            ),
          ] else if (displayUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tocá la foto para ampliar',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          _InfoBlock(product: product),
          const SizedBox(height: 16),
          ProductPricesPanel(prices: prices),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: canAdd ? AppDecorations.accentGradient : null,
                color: canAdd ? null : AppColors.border,
                borderRadius: AppDecorations.radiusMd,
                boxShadow: canAdd
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton.icon(
                onPressed: canAdd ? _addToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(
                  !product.inStock
                      ? 'SIN STOCK'
                      : canAdd
                          ? 'AGREGAR AL CARRITO'
                          : 'STOCK MÁXIMO EN CARRITO',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.product,
    required this.accent,
  });

  final Product product;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [accent, accent.withValues(alpha: 0.78)],
        ),
        borderRadius: AppDecorations.radiusMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.marcaUpper,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              product.type.label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
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
  });

  final String foto;
  final List<String> displayUrls;
  final String marca;
  final Color accent;
  final PageController pageController;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppDecorations.radiusMd,
        child: AspectRatio(
          aspectRatio: 4 / 3,
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
              if (onTap != null)
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
      ),
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.isArma) ...[
            _InfoLine(label: 'Modelo', value: product.modeloDisplay),
            const SizedBox(height: 10),
            _InfoLine(label: 'Calibre', value: product.calibre),
            const SizedBox(height: 10),
            _InfoLine(label: 'Ref. interna', value: product.codigo),
          ] else ...[
            _InfoLine(label: 'Código', value: product.codigo),
            const SizedBox(height: 10),
            _InfoLine(label: 'Calibre', value: product.calibre),
          ],
          if (product.stock != null) ...[
            const SizedBox(height: 14),
            _StockBadge(stock: product.stock!),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final sinStock = stock <= 0;
    final color = sinStock ? AppColors.danger : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppDecorations.radiusSm,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sinStock ? Icons.block : Icons.inventory_2_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            sinStock ? 'SIN STOCK' : 'STOCK: $stock',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
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
