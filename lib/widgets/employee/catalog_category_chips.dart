import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../theme/app_theme.dart';

class CatalogCategoryChips extends StatelessWidget {
  const CatalogCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ProductType? selected;
  final ValueChanged<ProductType?> onSelected;

  static const _labels = {
    null: 'Todo',
    ProductType.armaCorta: 'Cortas',
    ProductType.armaLarga: 'Largas',
    ProductType.municion: 'Munición',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _labels.entries.map((entry) {
          final isSelected = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? AppColors.textPrimary : AppColors.surfaceTouch,
              borderRadius: BorderRadius.circular(AppDecorations.radius),
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(AppDecorations.radius),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    border: Border.all(
                      color: isSelected ? AppColors.textPrimary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: AppText.bodySmall.copyWith(
                      color: isSelected ? AppColors.surface : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
