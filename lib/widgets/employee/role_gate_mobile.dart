import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../armenext_brand.dart';
import 'employee_role_widgets.dart';

/// Mock 01_Mob — selector de rol empleado / administración.
class RoleGateMobileLayout extends StatelessWidget {
  const RoleGateMobileLayout({
    super.key,
    required this.subtitle,
    required this.onEmployee,
    required this.onAdmin,
    this.showAdminCard = true,
    this.exchangeRate,
    this.exchangeUpdatedAt,
    this.header,
  });

  final String subtitle;
  final VoidCallback onEmployee;
  final VoidCallback onAdmin;
  final bool showAdminCard;
  final double? exchangeRate;
  final DateTime? exchangeUpdatedAt;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              children: [
                if (header != null) ...[
                  header!,
                  const SizedBox(height: 16),
                ],
                const RoleGateMobileHero(),
                const SizedBox(height: 28),
                Text(
                  '¿Cómo entrás?',
                  style: AppText.heading.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                RoleGateMobileCard(
                  label: 'Empleado',
                  subtitle: 'Consultar precios, stock y carrito',
                  icon: Icons.search_rounded,
                  variant: RoleGateMobileCardVariant.employee,
                  onTap: onEmployee,
                ),
                if (showAdminCard) ...[
                  const SizedBox(height: 12),
                  RoleGateMobileCard(
                    label: 'Administración',
                    subtitle: 'Editar productos, stock y tipo de cambio',
                    icon: Icons.tune_rounded,
                    variant: RoleGateMobileCardVariant.admin,
                    onTap: onAdmin,
                  ),
                ],
              ],
            ),
          ),
          if (exchangeRate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: DollarReferenceChip(
                rate: exchangeRate,
                updatedAt: exchangeUpdatedAt,
              ),
            ),
        ],
      ),
    );
  }
}

class RoleGateMobileHero extends StatelessWidget {
  const RoleGateMobileHero({super.key});

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
        const SizedBox(height: 20),
        Container(
          height: AppDecorations.hairline,
          color: AppColors.border,
        ),
      ],
    );
  }
}

enum RoleGateMobileCardVariant { employee, admin }

class RoleGateMobileCard extends StatelessWidget {
  const RoleGateMobileCard({
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
  final RoleGateMobileCardVariant variant;

  @override
  Widget build(BuildContext context) {
    final isEmployee = variant == RoleGateMobileCardVariant.employee;
    final iconBg = isEmployee ? AppColors.accent : AppColors.surfaceTouch;
    final iconColor = isEmployee ? AppColors.onAccent : AppColors.textPrimary;
    final iconBorder = isEmployee ? null : Border.all(color: AppColors.border);

    return Material(
      color: AppColors.surfaceRaised,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                  border: iconBorder,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textMuted.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
