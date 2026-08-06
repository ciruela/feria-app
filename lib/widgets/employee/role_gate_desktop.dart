import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../armenext_brand.dart';

/// Header del mock 01_Desk — lockup, tagline y divisor.
class RoleGateDesktopHero extends StatelessWidget {
  const RoleGateDesktopHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ArmenextLockup(width: 168, height: 40),
        const SizedBox(height: 8),
        Text(
          'Armas cortas · largas · munición',
          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        Container(
          height: AppDecorations.hairline,
          color: AppColors.border,
        ),
      ],
    );
  }
}

/// Card del mock 01_Desk — Empleado / Administración.
class RoleGateDesktopCard extends StatelessWidget {
  const RoleGateDesktopCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.variant,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final RoleGateCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final iconBg = variant == RoleGateCardVariant.employee
        ? AppColors.accent
        : AppColors.surfaceTouch;
    final iconColor = variant == RoleGateCardVariant.employee
        ? AppColors.onAccent
        : AppColors.textPrimary;

    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        hoverColor: AppColors.surfaceTouch.withValues(alpha: 0.35),
        child: Ink(
          height: 168,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border, width: AppDecorations.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: AppText.bodyLarge.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Entrar',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.textMuted.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum RoleGateCardVariant { employee, admin }

/// Layout completo del mock 01_Desk.
class RoleGateDesktopLayout extends StatelessWidget {
  const RoleGateDesktopLayout({
    super.key,
    required this.subtitle,
    required this.onEmployee,
    required this.onAdmin,
    this.showAdminCard = true,
  });

  final String subtitle;
  final VoidCallback onEmployee;
  final VoidCallback onAdmin;
  final bool showAdminCard;

  static const _contentMaxWidth = 680.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const RoleGateDesktopHero(),
                const SizedBox(height: 40),
                Text(
                  '¿Cómo entrás?',
                  style: AppText.heading.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 32),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: RoleGateDesktopCard(
                          label: 'Empleado',
                          subtitle: 'Consultar precios, stock y carrito',
                          icon: Icons.search_rounded,
                          variant: RoleGateCardVariant.employee,
                          onTap: onEmployee,
                        ),
                      ),
                      if (showAdminCard) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: RoleGateDesktopCard(
                            label: 'Administración',
                            subtitle: 'Editar productos, stock y tipo de cambio',
                            icon: Icons.tune_rounded,
                            variant: RoleGateCardVariant.admin,
                            onTap: onAdmin,
                          ),
                        ),
                      ],
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
