import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

/// Miniatura pensada para vendedores: foto real o “tarjeta” con código grande.
class ProductSellerThumb extends StatelessWidget {
  const ProductSellerThumb({
    super.key,
    required this.product,
    required this.accent,
    this.photoUrl,
    this.size = 88,
  });

  final Product product;
  final Color accent;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppDecorations.radiusMd,
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: photoUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) => _CodeThumb(
              product: product,
              accent: accent,
              size: size,
            ),
            errorWidget: (_, __, ___) => _CodeThumb(
              product: product,
              accent: accent,
              size: size,
            ),
          ),
        ),
      );
    }

    return _CodeThumb(product: product, accent: accent, size: size);
  }
}

class _CodeThumb extends StatelessWidget {
  const _CodeThumb({
    required this.product,
    required this.accent,
    required this.size,
  });

  final Product product;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = product.isMunicion && product.codigo.isNotEmpty
        ? product.codigo
        : product.modeloDisplay;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            product.isMunicion
                ? Icons.inventory_2_outlined
                : Icons.sports_martial_arts_outlined,
            color: accent,
            size: size * 0.24,
          ),
          const SizedBox(height: 4),
          Text(
            code,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 0.17,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              height: 1.05,
            ),
          ),
          if (product.calibre.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              product.calibre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: size * 0.11,
                fontWeight: FontWeight.w700,
                color: accent.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de chips para calibre, grains, caja, etc.
class ProductSellerTags extends StatelessWidget {
  const ProductSellerTags({
    super.key,
    required this.labels,
    this.accent = AppColors.primary,
  });

  final List<String> labels;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent.withValues(alpha: 0.95),
              letterSpacing: 0.2,
            ),
          ),
        );
      }).toList(),
    );
  }
}
