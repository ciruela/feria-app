import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            fotoUrl: product.fotoUrl,
            marca: product.marca,
            accent: _accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                const SizedBox(height: 14),
                ProductPricesPanel(prices: prices, compact: true),
                if (showAddButton) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: product.inStock
                            ? AppDecorations.accentGradient
                            : null,
                        color: product.inStock ? null : AppColors.border,
                        borderRadius: AppDecorations.radiusMd,
                        boxShadow: product.inStock
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
                        onPressed: product.inStock
                            ? () => _handleAddToCart(context, product)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: Text(product.inStock ? 'AGREGAR' : 'SIN STOCK'),
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
    var paymentMethod = PaymentMethod.lista;

    if (product.isArma) {
      final selected = await showPaymentMethodDialog(
        context,
        product: product,
      );
      if (selected == null || !context.mounted) return;
      paymentMethod = selected;
    }

    context.read<CartService>().addProduct(
          product,
          paymentMethod: paymentMethod,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                product.isArma
                    ? '${product.modeloDisplay} · ${paymentMethod.label}'
                    : '${product.codigo} agregado',
              ),
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

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({
    required this.foto,
    required this.fotoUrl,
    required this.marca,
    required this.accent,
  });

  final String foto;
  final String fotoUrl;
  final String marca;
  final Color accent;

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
              accent.withValues(alpha: 0.05),
              AppColors.surfaceMuted,
            ],
          ),
        ),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    if (fotoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: fotoUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => _Placeholder(marca: marca, loading: true),
        errorWidget: (_, __, ___) => _buildLocalOrPlaceholder(),
      );
    }

    return _buildLocalOrPlaceholder();
  }

  Widget _buildLocalOrPlaceholder() {
    if (foto.isNotEmpty) {
      return Image.asset(
        foto,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Placeholder(marca: marca),
      );
    }

    return _Placeholder(marca: marca);
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
