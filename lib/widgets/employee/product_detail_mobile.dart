import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../models/product_prices.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'catalog_product_list.dart';
import 'product_detail_spec_table.dart';

/// Mock 04_Mob — detalle de producto.
class ProductDetailMobileLayout extends StatelessWidget {
  const ProductDetailMobileLayout({
    super.key,
    required this.product,
    required this.prices,
    required this.showArs,
    required this.photoGallery,
    required this.canAdd,
    required this.onBack,
    required this.onAddToCart,
  });

  final Product product;
  final ProductPrices prices;
  final bool showArs;
  final Widget photoGallery;
  final bool canAdd;
  final VoidCallback onBack;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductDetailMobileHeader(
          categoryLabel: product.type.label.toUpperCase(),
          onBack: onBack,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              photoGallery,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      catalogProductTitle(product),
                      style: AppText.heading.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.codigo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.codigo,
                        style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ProductDetailSpecTable(product: product),
                    const SizedBox(height: 16),
                    ProductDetailMobilePricing(
                      prices: prices,
                      showArs: showArs,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: canAdd ? onAddToCart : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.surfaceTouch,
                        disabledForegroundColor: AppColors.textMuted,
                        minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(
                        !product.inStock
                            ? 'Sin stock'
                            : canAdd
                                ? 'Agregar al carrito'
                                : 'Stock máximo en carrito',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ProductDetailMobileHeader extends StatelessWidget {
  const ProductDetailMobileHeader({
    super.key,
    required this.categoryLabel,
    required this.onBack,
  });

  final String categoryLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              label: const Text('Catálogo'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDecorations.radius),
              ),
              child: Text(
                categoryLabel,
                style: AppText.label.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailMobilePricing extends StatelessWidget {
  const ProductDetailMobilePricing({
    super.key,
    required this.prices,
    required this.showArs,
  });

  final ProductPrices prices;
  final bool showArs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: showArs
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'PRECIO DE LISTA',
                      style: AppText.label.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(formatUsd(prices.usd), style: AppText.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatArs(prices.lista),
                  style: AppText.number.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Text(
              'Precios en pesos no disponibles: falta el tipo de cambio.',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
    );
  }
}
