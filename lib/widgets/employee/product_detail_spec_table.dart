import 'package:flutter/material.dart';

import '../../config/stock_config.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';

/// Tabla de specs compartida mock 04 (mobile + desktop).
class ProductDetailSpecTable extends StatelessWidget {
  const ProductDetailSpecTable({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final lowStock = isLowStock(product.stock);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDecorations.radius),
      ),
      child: Column(
        children: [
          if (product.isArma) ...[
            _SpecRow(label: 'Modelo', value: product.modeloDisplay),
            const Divider(height: 1, color: AppColors.border),
            _SpecRow(label: 'Calibre', value: product.calibre),
            const Divider(height: 1, color: AppColors.border),
            _SpecRow(label: 'Ref. interna', value: product.codigo),
          ] else ...[
            _SpecRow(label: 'Código', value: product.codigo),
            const Divider(height: 1, color: AppColors.border),
            _SpecRow(label: 'Calibre', value: product.calibre),
          ],
          if (product.stock != null) ...[
            const Divider(height: 1, color: AppColors.border),
            _SpecRow(
              label: 'Stock',
              value: lowStock
                  ? '${product.stock} u. · ÚLTIMAS UNIDADES'
                  : '${product.stock} ${product.isMunicion ? 'cajas' : 'u.'}',
              accent: lowStock,
            ),
          ],
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
