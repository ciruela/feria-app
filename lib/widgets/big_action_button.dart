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
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDecorations.radiusLg,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDecorations.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: [AppDecorations.cardShadow],
          ),
          child: ClipRRect(
            borderRadius: AppDecorations.radiusLg,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: 0.18),
                              accent.withValues(alpha: 0.06),
                            ],
                          ),
                          borderRadius: AppDecorations.radiusMd,
                          border: Border.all(color: accent.withValues(alpha: 0.22)),
                        ),
                        child: Icon(icon, size: 34, color: accent),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: accent,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
