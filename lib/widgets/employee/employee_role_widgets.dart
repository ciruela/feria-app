import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../armenext_brand.dart';

class DollarReferenceChip extends StatelessWidget {
  const DollarReferenceChip({
    super.key,
    required this.rate,
    this.updatedAt,
    this.compact = false,
  });

  final double? rate;
  final DateTime? updatedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (rate == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DÓLAR',
              style: AppText.label.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
            Text(
              formatArs(rate!).replaceFirst(r'$ ', ''),
              style: AppText.number.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dólar de referencia',
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  formatArs(rate!).replaceFirst(r'$ ', ''),
                  style: AppText.number.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (updatedAt != null)
            Text(
              'Cargado ${formatTime(updatedAt!)}',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class RoleEntryCard extends StatelessWidget {
  const RoleEntryCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlighted ? AppColors.accent : AppColors.surfaceTouch,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: highlighted ? AppColors.onAccent : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Text(label, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppText.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Entrar',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleGateHero extends StatelessWidget {
  const RoleGateHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ArmenextLockup(width: 150, height: 36),
        const SizedBox(height: 10),
        const Text(
          'Armas cortas · largas · munición',
          style: AppText.bodySmall,
        ),
        const SizedBox(height: 20),
        Container(
          height: AppDecorations.hairline,
          color: AppColors.border,
        ),
      ],
    );
  }
}
