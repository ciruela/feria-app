import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/product.dart';
import '../../models/product_prices.dart';
import '../../services/exchange_rate_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'catalog_desktop_header.dart';
import 'catalog_product_list.dart';
import 'product_detail_spec_table.dart';

/// Mock 04_Desk — detalle de producto con header de catálogo.
class ProductDetailDesktopLayout extends StatelessWidget {
  const ProductDetailDesktopLayout({
    super.key,
    required this.product,
    required this.prices,
    required this.exchangeRate,
    required this.showArs,
    required this.photoGallery,
    required this.canAdd,
    required this.sellerName,
    required this.sellerInitial,
    required this.lowStockCount,
    required this.totalLoaded,
    required this.onBack,
    required this.onAddToCart,
    required this.onChangeSeller,
  });

  final Product product;
  final ProductPrices prices;
  final ExchangeRateService exchangeRate;
  final bool showArs;
  final Widget photoGallery;
  final bool canAdd;
  final String sellerName;
  final String sellerInitial;
  final int lowStockCount;
  final int totalLoaded;
  final VoidCallback onBack;
  final VoidCallback onAddToCart;
  final VoidCallback onChangeSeller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CatalogDesktopHeader(
            sellerName: sellerName,
            sellerInitial: sellerInitial,
            exchangeRate: exchangeRate,
            lowStockCount: lowStockCount,
            showing: totalLoaded,
            totalLoaded: totalLoaded,
            onChangeSeller: onChangeSeller,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
            child: _ProductDetailCard(
              product: product,
              prices: prices,
              exchangeRate: exchangeRate,
              showArs: showArs,
              photoGallery: photoGallery,
              canAdd: canAdd,
              onBack: onBack,
              onAddToCart: onAddToCart,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductDetailCard extends StatelessWidget {
  const _ProductDetailCard({
    required this.product,
    required this.prices,
    required this.exchangeRate,
    required this.showArs,
    required this.photoGallery,
    required this.canAdd,
    required this.onBack,
    required this.onAddToCart,
  });

  final Product product;
  final ProductPrices prices;
  final ExchangeRateService exchangeRate;
  final bool showArs;
  final Widget photoGallery;
  final bool canAdd;
  final VoidCallback onBack;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      catalogProductTitle(product),
                      style: AppText.heading.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (product.codigo.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(product.codigo, style: AppText.bodySmall),
                    ],
                    const SizedBox(height: 20),
                    ProductDetailSpecTable(product: product),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                flex: 4,
                child: _DetailPricingColumn(
                  prices: prices,
                  showArs: showArs,
                  exchangeRate: exchangeRate,
                  canAdd: canAdd,
                  inStock: product.inStock,
                  onAddToCart: onAddToCart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailPricingColumn extends StatelessWidget {
  const _DetailPricingColumn({
    required this.prices,
    required this.showArs,
    required this.exchangeRate,
    required this.canAdd,
    required this.inStock,
    required this.onAddToCart,
  });

  final ProductPrices prices;
  final bool showArs;
  final ExchangeRateService exchangeRate;
  final bool canAdd;
  final bool inStock;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showArs) ...[
          Text(
            'PRECIO DE LISTA',
            style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 20),
          _PaymentRow(
            label: 'Efectivo (-5%)',
            value: formatArs(prices.efectivo),
            highlight: true,
          ),
          _PaymentRow(label: 'Dólar billete', value: formatArs(prices.lista)),
          _PaymentRow(label: 'Transferencia', value: formatArs(prices.lista)),
          _PaymentRow(label: 'Débito', value: formatArs(prices.debito)),
          _PaymentRow(label: '1 cuota', value: formatArs(prices.tarjeta1)),
          _CuotaRow(count: 3, total: prices.tarjeta3, cuota: prices.cuota3),
          _CuotaRow(count: 6, total: prices.tarjeta6, cuota: prices.cuota6),
          _CuotaRow(count: 9, total: prices.tarjeta9, cuota: prices.cuota9),
          _CuotaRow(count: 12, total: prices.tarjeta12, cuota: prices.cuota12),
          _CuotaRow(count: 18, total: prices.tarjeta18, cuota: prices.cuota18),
          if (exchangeRate.hasServerRate && exchangeRate.updatedAt != null) ...[
            const SizedBox(height: 16),
            Text(
              'Calculado con el dólar '
              '${NumberFormat('#,##0', 'es_AR').format(exchangeRate.rate)} · '
              '${formatDateTime(exchangeRate.updatedAt!)}',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ] else
          Text(
            'Precios en pesos no disponibles: falta el tipo de cambio.',
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: canAdd ? onAddToCart : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
          ),
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(
            !inStock
                ? 'Sin stock'
                : canAdd
                    ? 'Agregar al carrito'
                    : 'Stock máximo en carrito',
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.bodySmall),
          ),
          Text(
            value,
            style: AppText.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CuotaRow extends StatelessWidget {
  const _CuotaRow({
    required this.count,
    required this.total,
    required this.cuota,
  });

  final int count;
  final double total;
  final double cuota;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count cuotas: $count x ${formatArs(cuota)}',
              style: AppText.bodySmall,
            ),
          ),
          Text(
            formatArs(total),
            style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
