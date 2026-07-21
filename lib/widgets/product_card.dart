import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_prices_panel.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.showAddButton = true,
  });

  final Product product;
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final prices = PricingService().pricesFor(
      product,
      exchangeRate,
      pricingSettings,
    );

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text(
              product.marcaUpper,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _ProductPhoto(
            foto: product.foto,
            fotoUrl: product.fotoUrl,
            marca: product.marca,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                  const SizedBox(height: 10),
                  _StockBadge(stock: product.stock!),
                ],
                const SizedBox(height: 14),
                ProductPricesPanel(prices: prices, compact: true),
                if (showAddButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: product.inStock
                          ? () {
                              context.read<CartService>().addProduct(product);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Agregado al carrito'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('AGREGAR'),
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
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyLarge,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    final sinStock = stock <= 0;
    final color = sinStock ? const Color(0xFFB42318) : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        sinStock ? 'SIN STOCK' : 'STOCK: $stock',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({
    required this.foto,
    required this.fotoUrl,
    required this.marca,
  });

  final String foto;
  final String fotoUrl;
  final String marca;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: const Color(0xFFECEFF4),
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
            const CircularProgressIndicator()
          else
            Icon(
              Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          const SizedBox(height: 12),
          Text(
            marca.toUpperCase(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
