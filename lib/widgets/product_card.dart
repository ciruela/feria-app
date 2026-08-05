import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../models/product_prices.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/product_photo_service.dart';
import '../theme/app_theme.dart';
import '../screens/product_detail_screen.dart';
import 'add_to_cart_sheet.dart';
import 'added_to_cart_sheet.dart';
import 'product_prices_panel.dart';
import 'product_seller_visual.dart';

enum ProductCardLayout { list, grid }

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.showAddButton = true,
    this.layout = ProductCardLayout.grid,
  });

  final Product product;
  final bool showAddButton;
  final ProductCardLayout layout;

  bool get _isList => layout == ProductCardLayout.list;

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
    final prices = context.read<PricingService>().pricesFor(
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
          Container(
            padding: EdgeInsets.fromLTRB(
              18,
              _isList ? 10 : 14,
              18,
              _isList ? 10 : 14,
            ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _isList ? 18 : 22,
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
          if (showAddButton) _buildActionRow(context, canAdd),
          if (_isList)
            _buildListBody(
              context,
              prices,
              showArs: exchangeRate.hasServerRate,
            )
          else
            Expanded(
              child: _buildGridBody(
                context,
                prices,
                showArs: exchangeRate.hasServerRate,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, bool canAdd) {
    final btnHeight = _isList ? 44.0 : 48.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, _isList ? 10 : 12, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _openDetail(context),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(btnHeight),
                side: const BorderSide(color: AppColors.border),
                padding: EdgeInsets.zero,
              ),
              child: const Text('DETALLE'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
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
                onPressed: canAdd
                    ? () => _handleAddToCart(context, product)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: Size.fromHeight(btnHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: Text(
                  !product.inStock
                      ? 'SIN STOCK'
                      : canAdd
                          ? 'AGREGAR'
                          : 'MÁX.',
                  style: TextStyle(fontSize: _isList ? 13 : 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody(
    BuildContext context,
    ProductPrices prices, {
    required bool showArs,
  }) {
    final photoUrls = ProductPhotoService.displayUrls(product.fotoUrls);
    final photoUrl = photoUrls.isNotEmpty ? photoUrls.first : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: ProductSellerThumb(
              product: product,
              accent: _accent,
              photoUrl: photoUrl,
              size: 88,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.isMunicion && product.codigo.isNotEmpty)
                            Text(
                              product.codigo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            )
                          else
                            Text(
                              product.modeloDisplay,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            product.sellerShortTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (product.stock != null) ...[
                      const SizedBox(width: 8),
                      _StockBadge(
                        stock: product.stock!,
                        unitLabel: product.isMunicion ? 'CAJAS' : null,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (product.sellerTagLabels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ProductSellerTags(
                    labels: product.sellerTagLabels,
                    accent: _accent,
                  ),
                ],
                const SizedBox(height: 8),
                ProductPricesPanel(
                  prices: prices,
                  compact: true,
                  showArs: showArs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBody(
    BuildContext context,
    ProductPrices prices, {
    required bool showArs,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetail(context),
              borderRadius: AppDecorations.radiusMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: AppDecorations.radiusMd,
                    child: _ProductPhoto(
                      foto: product.foto,
                      fotoUrls:
                          ProductPhotoService.displayUrls(product.fotoUrls),
                      marca: product.marca,
                      accent: _accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._buildInfoRows(context),
                  if (product.stock != null) ...[
                    const SizedBox(height: 12),
                    _StockBadge(
                      stock: product.stock!,
                      unitLabel: product.isMunicion ? 'CAJAS' : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ProductPricesPanel(
            prices: prices,
            compact: true,
            showArs: showArs,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoRows(BuildContext context) {
    if (product.isArma) {
      return [
        _InfoRow(label: 'MODELO', value: product.modeloDisplay),
        const SizedBox(height: 10),
        _InfoRow(label: 'CALIBRE', value: product.calibre),
      ];
    }
    return [
      _InfoRow(label: 'CÓDIGO', value: product.codigo),
      if (product.calibre.isNotEmpty) ...[
        const SizedBox(height: 10),
        _InfoRow(label: 'CALIBRE', value: product.calibre),
      ],
      if (product.granos.isNotEmpty) ...[
        const SizedBox(height: 10),
        _InfoRow(label: 'PESO PUNTA', value: product.granos),
      ],
      if (product.descripcion.isNotEmpty) ...[
        const SizedBox(height: 10),
        _InfoRow(
          label: 'DETALLE',
          value: product.descripcion,
          maxLines: 3,
        ),
      ],
    ];
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  Future<void> _handleAddToCart(BuildContext context, Product product) async {
    final action = await promptAddToCart(context, product);
    if (!context.mounted) return;
    await handleAddedToCartNavigation(context, action);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.maxLines,
  });

  final String label;
  final String value;
  final int? maxLines;

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
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
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
  const _StockBadge({
    required this.stock,
    this.unitLabel,
    this.compact = false,
  });

  final int stock;
  final String? unitLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sinStock = stock <= 0;
    final color = sinStock ? AppColors.danger : AppColors.success;
    final unit = unitLabel != null ? ' ${unitLabel!}' : '';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 14,
        vertical: compact ? 4 : 10,
      ),
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
            size: compact ? 14 : 20,
          ),
          SizedBox(width: compact ? 4 : 8),
          Text(
            sinStock ? 'SIN STOCK' : 'STOCK: $stock$unit',
            style: TextStyle(
              fontSize: compact ? 12 : 16,
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
    final photo = Container(
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
    );

    return AspectRatio(aspectRatio: 4 / 3, child: photo);
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
