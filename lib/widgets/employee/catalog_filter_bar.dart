import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Barra de filtros rápidos para el catálogo del vendedor (marca / calibre).
/// Complementa a las categorías (tipo). Pensada para que el vendedor acote
/// rápido sin escribir. Funciona igual en mobile y desktop.
class CatalogFilterBar extends StatelessWidget {
  const CatalogFilterBar({
    super.key,
    required this.marcas,
    required this.calibres,
    required this.selectedMarca,
    required this.selectedCalibre,
    required this.onMarcaChanged,
    required this.onCalibreChanged,
    required this.onClear,
    this.desktopHandoff = false,
  });

  final List<String> marcas;
  final List<String> calibres;
  final String? selectedMarca;
  final String? selectedCalibre;
  final ValueChanged<String?> onMarcaChanged;
  final ValueChanged<String?> onCalibreChanged;
  final VoidCallback onClear;
  final bool desktopHandoff;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = desktopHandoff ? 28.0 : 20.0;
    final hasFilters = selectedMarca != null || selectedCalibre != null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          _FilterDropdown(
            label: 'Marca',
            icon: Icons.sell_outlined,
            value: selectedMarca,
            options: marcas,
            onChanged: onMarcaChanged,
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            label: 'Calibre',
            icon: Icons.adjust_rounded,
            value: selectedCalibre,
            options: calibres,
            onChanged: onCalibreChanged,
          ),
          if (hasFilters) ...[
            const SizedBox(width: 8),
            _ClearChip(onTap: onClear),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    final enabled = options.isNotEmpty;

    return PopupMenuButton<String?>(
      enabled: enabled,
      tooltip: label,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 200, maxHeight: 360),
      color: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (selected) => onChanged(selected),
      itemBuilder: (context) => <PopupMenuEntry<String?>>[
        PopupMenuItem<String?>(
          value: null,
          child: Text('Todas las ${label.toLowerCase()}s'),
        ),
        const PopupMenuDivider(),
        ...options.map(
          (option) => PopupMenuItem<String?>(
            value: option,
            child: Row(
              children: [
                Expanded(child: Text(option)),
                if (option == value)
                  const Icon(Icons.check_rounded,
                      size: 18, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ],
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.textPrimary : AppColors.surfaceTouch,
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(
              color: isActive ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.canvas : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? value! : label,
                style: AppText.bodySmall.copyWith(
                  color: isActive ? AppColors.canvas : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isActive ? AppColors.canvas : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearChip extends StatelessWidget {
  const _ClearChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Limpiar',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
