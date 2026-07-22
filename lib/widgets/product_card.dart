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
import '../screens/product_detail_screen.dart';
import 'added_to_cart_sheet.dart';
import 'payment_method_dialog.dart';
import 'product_prices_panel.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.showAddButton = true,
  });

  final Product product;
  final bool showAddButton;

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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: [AppDecorations.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [_accent, _accent.withValues(alpha: 0.78)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.marcaUpper,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                  ),
                  _ProductPhoto(
                    foto: product.foto,
                    fotoUrls: ProductPhotoService.displayUrls(product.fotoUrls),
                    marca: product.marca,
                    accent: _accent,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.isArma) ...[
                          _InfoRow(label: 'MODELO', value: product.modeloDisplay),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'CALIBRE', value: product.calibre),
                        ] else ...[
                          _InfoRow(label: 'CÓDIGO', value: product.codigo),
                          const SizedBox(height: 10),
                          _InfoRow(label: 'CALIBRE', value: product.calibre),
                        ],
                        if (product.stock != null) ...[
                          const SizedBox(height: 12),
                          _StockBadge(stock: product.stock!),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: _accent.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VER DETALLE Y FOTOS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _accent.withValues(alpha: 0.85),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductPricesPanel(prices: prices, compact: true),
                if (showAddButton) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: canAdd
                            ? AppDecorations.accentGradient
                            : null,
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
                        onPressed: canAdd
                            ? () => _handleAddToCart(context, product)
                            : null,
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
                                  ? 'AGREGAR'
                                  : 'MÁX. EN CARRITO',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddToCart(BuildContext context, Product product) async {
    final cart = context.read<CartService>();

    if (product.isArma) {
      final selection = await showWeaponPaymentDialog(
        context,
        product: product,
      );
      if (selection == null || !context.mounted) return;

      final result = cart.addWeaponPayment(product, selection);
      if (!context.mounted) return;

      if (result == CartAddResult.stockLimitReached) {
        showStockLimitMessage(context, product);
        return;
      }

      final message = selection.isDual
          ? '${product.modeloDisplay} · ${selection.first.shortLabel} + ${selection.second!.shortLabel}'
          : '${product.modeloDisplay} · ${selection.first.label}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
      return;
    }

    final method = await showSinglePaymentDialog(
      context,
      product: product,
    );
    if (method == null || !context.mounted) return;

    final result = cart.addProduct(product, paymentMethod: method);
    if (!context.mounted) return;

    if (result == CartAddResult.stockLimitReached) {
      showStockLimitMessage(context, product);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${product.codigo} agregado · ${method.shortLabel}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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

class _ProductPhoto extends StatefulWidget {
  const _ProductPhoto({
    required this.foto,
    required this.fotoUrls,
    required this.marca,
    required this.accent,
  });

  final String foto;
  final List<String> fotoUrls;
  final String marca;
  final Color accent;

  @override
  State<_ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<_ProductPhoto> {
  late final PageController _pageController;
  int _page = 0;

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

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.accent.withValues(alpha: 0.05),
              AppColors.surfaceMuted,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildImage(),
            if (widget.fotoUrls.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.fotoUrls.length, (index) {
                    final active = index == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? widget.accent
                            : widget.accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.fotoUrls.isNotEmpty) {
      if (widget.fotoUrls.length == 1) {
        return _networkImage(widget.fotoUrls.first);
      }

      return PageView.builder(
        controller: _pageController,
        itemCount: widget.fotoUrls.length,
        onPageChanged: (index) => setState(() => _page = index),
        itemBuilder: (_, index) => _networkImage(widget.fotoUrls[index]),
      );
    }

    return _buildLocalOrPlaceholder();
  }

  Widget _networkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => _Placeholder(marca: widget.marca, loading: true),
      errorWidget: (_, __, ___) => _buildLocalOrPlaceholder(),
    );
  }

  Widget _buildLocalOrPlaceholder() {
    if (widget.foto.isNotEmpty) {
      return Image.asset(
        widget.foto,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Placeholder(marca: widget.marca),
      );
    }

    return _Placeholder(marca: widget.marca);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.marca,
    this.loading = false,
  });

  final String marca;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const CircularProgressIndicator(color: AppColors.primary)
          else
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_back_outlined,
                size: 42,
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
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
    );
  }
}
