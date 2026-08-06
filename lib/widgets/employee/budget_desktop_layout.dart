import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Barra superior mock 07_Desk: « Carrito · Presupuesto · sesión.
class BudgetDesktopHeader extends StatelessWidget {
  const BudgetDesktopHeader({
    super.key,
    required this.sellerName,
    this.updatedAt,
    required this.onBack,
  });

  final String? sellerName;
  final DateTime? updatedAt;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final sessionParts = <String>[];
    if (sellerName != null) sessionParts.add('Atiende $sellerName');
    if (updatedAt != null) sessionParts.add(formatDateTime(updatedAt!));

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Carrito'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Presupuesto',
            style: AppText.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (sessionParts.isNotEmpty)
            Text(
              sessionParts.join(' · '),
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Shell mock 07_Desk: sidebar de controles + lienzo de preview.
class BudgetDesktopLayout extends StatelessWidget {
  const BudgetDesktopLayout({
    super.key,
    required this.header,
    required this.sidebar,
    required this.preview,
  });

  final Widget header;
  final Widget sidebar;
  final Widget preview;

  static const sidebarWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: sidebarWidth, child: sidebar),
                const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                Expanded(child: preview),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String formatReferenceRate(double rate) {
  return NumberFormat('#,##0', 'es_AR').format(rate);
}
