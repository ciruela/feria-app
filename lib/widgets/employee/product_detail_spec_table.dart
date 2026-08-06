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

    final rows = <Widget>[];
    void addRow(String label, String value, {bool accent = false}) {
      if (value.trim().isEmpty) return;
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, color: AppColors.border));
      }
      rows.add(_SpecRow(label: label, value: value, accent: accent));
    }

    // Datos completos para que el vendedor se los pase al cliente.
    addRow('Marca', product.marca);
    if (product.isArma) {
      addRow('Modelo', product.modeloDisplay);
      addRow('Calibre', product.calibre);
      addRow('Ref. interna', product.codigo);
    } else {
      addRow('Código', product.codigo);
      addRow('Calibre', product.calibre);
      addRow('Modelo', product.modelo);
    }

    if (product.stock != null) {
      final unit = product.isMunicion ? 'cajas' : 'u.';
      addRow(
        'Stock',
        '${product.stock} $unit${lowStock ? ' · ÚLTIMAS UNIDADES' : ''}',
        accent: lowStock,
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDecorations.radius),
      ),
      child: Column(children: rows),
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
