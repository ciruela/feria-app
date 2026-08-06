import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/stock_config.dart';
import '../../models/product.dart';
import '../../services/cart_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/pricing_service.dart';
import '../../services/pricing_settings_service.dart';
import '../../services/product_photo_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../add_to_cart_sheet.dart';
import '../added_to_cart_sheet.dart';
import '../product_seller_visual.dart';
import '../../screens/product_detail_screen.dart';

String catalogProductTitle(Product product) {
  if (product.isArma) {
    return '${product.marcaUpper} ${product.modeloDisplay}'.trim();
  }

  final short = product.sellerShortTitle;
  if (product.marca.isNotEmpty && short.isNotEmpty) {
    return '${product.marcaUpper} $short'.trim();
  }
  if (short.isNotEmpty) return short;

  final description = product.descripcion.trim();
  if (description.isNotEmpty) {
    return description.length > 56 ? '${description.substring(0, 53)}…' : description;
  }

  if (product.codigo.isNotEmpty) return product.codigo;
  return product.marca.isNotEmpty ? product.marcaUpper : 'Munición';
}

String catalogProductSubtitle(Product product) {
  final parts = <String>[];

  if (product.isMunicion) {
    if (product.codigo.isNotEmpty) parts.add(product.codigo);
    if (product.calibre.isNotEmpty) parts.add('Cal. ${product.calibre}');
    if (product.modelo.isNotEmpty) parts.add(product.modelo);
    if (product.stock != null) parts.add('${product.stock} cajas');
    return parts.join(' · ');
  }

  if (product.calibre.isNotEmpty) {
    parts.add('Cal. ${product.calibre}');
  }
  if (product.stock != null) {
    parts.add('${product.stock} u.');
  }
  return parts.join(' · ');
}

class CatalogProductRow extends StatelessWidget {
  const CatalogProductRow({super.key, required this.product});

  final Product product;

  Future<void> _addToCart(BuildContext context) async {
    final action = await promptAddToCart(context, product);
    if (!context.mounted) return;
    await handleAddedToCartNavigation(context, action);
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final prices = context.read<PricingService>().pricesFor(
          product,
          exchangeRate,
          pricingSettings,
        );
    final photoUrls = ProductPhotoService.displayUrls(product.fotoUrls);
    final lowStock = isLowStock(product.stock);

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductSellerThumb(
                product: product,
                accent: AppColors.accent,
                photoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalogProductTitle(product),
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (catalogProductSubtitle(product).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        catalogProductSubtitle(product),
                        style: AppText.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (product.isMunicion && product.sellerTagLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ProductSellerTags(
                        labels: product.sellerTagLabels,
                        accent: AppColors.accent,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lowStock)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.accent,
                        size: 18,
                      ),
                    ),
                  if (exchangeRate.hasServerRate)
                    Text(
                      formatArs(prices.lista),
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                  Text(
                    formatUsd(prices.usd),
                    style: AppText.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openDetail(context),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: product.inStock ? () => _addToCart(context) : null,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                  label: const Text('Agregar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CatalogProductTable extends StatelessWidget {
  const CatalogProductTable({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 4, child: _HeaderCell('PRODUCTO')),
              Expanded(flex: 2, child: _HeaderCell('CÓDIGO')),
              Expanded(flex: 2, child: _HeaderCell('STOCK')),
              Expanded(flex: 2, child: _HeaderCell('USD')),
              Expanded(flex: 2, child: _HeaderCell('LISTA')),
              SizedBox(width: 88),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              return CatalogProductTableRow(product: products[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tocá la fila para ver el detalle · el carrito suma una unidad',
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ),
              Text(
                'Lista y efectivo · el resto de las formas de pago, en el detalle',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 11),
    );
  }
}

class CatalogProductTableRow extends StatelessWidget {
  const CatalogProductTableRow({super.key, required this.product});

  final Product product;

  Future<void> _addToCart(BuildContext context) async {
    final action = await promptAddToCart(context, product);
    if (!context.mounted) return;
    await handleAddedToCartNavigation(context, action);
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final cartQty = context.watch<CartService>().quantityInCart(product.id);
    final prices = context.read<PricingService>().pricesFor(
          product,
          exchangeRate,
          pricingSettings,
        );
    final photoUrls = ProductPhotoService.displayUrls(product.fotoUrls);
    final lowStock = isLowStock(product.stock);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(context),
        hoverColor: AppColors.surfaceTouch,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                ProductSellerThumb(
                  product: product,
                  accent: AppColors.accent,
                  photoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catalogProductTitle(product),
                        style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        catalogProductSubtitle(product),
                        style: AppText.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cartQty > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$cartQty en carrito',
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(product.codigo, style: AppText.code),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lowStock)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.accent,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'BAJO STOCK',
                        style: AppText.label.copyWith(
                          color: AppColors.accent,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                if (lowStock) const SizedBox(height: 4),
                Text(
                  product.stock == null
                      ? '—'
                      : '${product.stock} ${product.isMunicion ? 'cajas' : 'u.'}',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(formatUsd(prices.usd), style: AppText.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(
              exchangeRate.hasServerRate ? formatArs(prices.lista) : '—',
              style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TableActionButton(
                  icon: Icons.visibility_outlined,
                  background: AppColors.surfaceTouch,
                  foreground: AppColors.textPrimary,
                  onPressed: () => _openDetail(context),
                ),
                const SizedBox(width: 8),
                _TableActionButton(
                  icon: Icons.shopping_bag_outlined,
                  background: AppColors.accent,
                  foreground: AppColors.onAccent,
                  onPressed: product.inStock ? () => _addToCart(context) : null,
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: foreground),
        ),
      ),
    );
  }
}
