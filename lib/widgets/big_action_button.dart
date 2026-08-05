import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BigActionButton extends StatelessWidget {
  const BigActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.accentColor,
    this.primary = false,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;
  /// Tarjeta destacada (empleado): fondo surfaceTouch sin borde.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.accent;
    final highlighted = primary || accent == AppColors.accent;

    return Material(
      color: highlighted ? AppColors.surfaceTouch : AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppDecorations.tapMin),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: highlighted
                ? null
                : Border.all(
                    color: AppColors.border,
                    width: AppDecorations.hairline,
                  ),
          ),
          child: Row(
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: AppText.bodySmall),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
