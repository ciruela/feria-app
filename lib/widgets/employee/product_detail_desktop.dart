import 'package:flutter/material.dart';

import '../../config/stock_config.dart';
import '../../models/product.dart';
import '../../models/product_prices.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/product_prices_panel.dart';

/// Mock 04_Desk — cuerpo del detalle dentro del shell empleado.
class ProductDetailDesktopBody extends StatelessWidget {
  const ProductDetailDesktopBody({
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
    final lowStock = isLowStock(product.stock);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  label: const Text('Volver al catálogo'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                  ),
                  child: Text(
                    product.type.label.toUpperCase(),
                    style: AppText.label.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDecorations.radius),
                        child: photoGallery,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        product.isArma ? product.modeloDisplay : product.codigo,
                        style: AppText.heading.copyWith(fontSize: 26),
                      ),
                      if (product.codigo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(product.codigo, style: AppText.bodySmall),
                      ],
                      const SizedBox(height: 20),
                      _SpecTable(product: product, lowStock: lowStock),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showArs) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatArs(prices.lista),
                              style: AppText.number.copyWith(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(formatUsd(prices.usd), style: AppText.bodySmall),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      ProductPricesPanel(prices: prices, showArs: showArs),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: canAdd ? onAddToCart : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
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
          ],
        ),
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.product, required this.lowStock});

  final Product product;
  final bool lowStock;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (product.isArma) ...[
          _SpecRow(label: 'Modelo', value: product.modeloDisplay),
          _SpecRow(label: 'Calibre', value: product.calibre),
          _SpecRow(label: 'Ref. interna', value: product.codigo),
        ] else ...[
          _SpecRow(label: 'Código', value: product.codigo),
          _SpecRow(label: 'Calibre', value: product.calibre),
        ],
        if (product.stock != null)
          _SpecRow(
            label: 'Stock',
            value: lowStock
                ? '${product.stock} u. · ÚLTIMAS UNIDADES'
                : '${product.stock} ${product.isMunicion ? 'cajas' : 'u.'}',
            accent: lowStock,
          ),
      ],
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label.toUpperCase(),
              style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: accent ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
