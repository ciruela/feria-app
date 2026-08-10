import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../theme/app_theme.dart';

class CatalogCategoryChips extends StatelessWidget {
  const CatalogCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.desktopHandoff = false,
  });

  final ProductType? selected;
  final ValueChanged<ProductType?> onSelected;
  final bool desktopHandoff;

  static const _baseLabels = {
    null: 'Todo',
    ProductType.armaCorta: 'Cortas',
    ProductType.armaLarga: 'Largas',
    ProductType.municion: 'Munición',
    ProductType.accesorios: 'Accesorios',
  };

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = desktopHandoff ? 28.0 : 20.0;
    final labels = _baseLabels;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: labels.entries.map((entry) {
          final isSelected = selected == entry.key;
          final selectedBg =
              desktopHandoff ? AppColors.textPrimary : AppColors.textPrimary;
          final selectedFg =
              desktopHandoff ? AppColors.canvas : AppColors.surface;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected ? selectedBg : AppColors.surfaceTouch,
              borderRadius: BorderRadius.circular(AppDecorations.radius),
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(AppDecorations.radius),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    border: Border.all(
                      color: isSelected ? selectedBg : AppColors.border,
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: AppText.bodySmall.copyWith(
                      color: isSelected ? selectedFg : AppColors.textMuted,
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
