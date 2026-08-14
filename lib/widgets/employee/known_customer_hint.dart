import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Indica que el DNI ingresado coincide con un cliente ya registrado.
class KnownCustomerHint extends StatelessWidget {
  const KnownCustomerHint({
    super.key,
    required this.saleCount,
    required this.lookingUp,
  });

  final int? saleCount;
  final bool lookingUp;

  @override
  Widget build(BuildContext context) {
    if (lookingUp) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Buscando cliente…',
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      );
    }

    final count = saleCount;
    if (count == null || count <= 0) {
      return const SizedBox.shrink();
    }

    final label = count == 1
        ? 'Cliente conocido · 1 compra'
        : 'Cliente conocido · $count compras';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_outlined, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppText.bodySmall.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
