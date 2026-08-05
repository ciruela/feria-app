import 'package:flutter/material.dart';

import '../screens/auth/tenant_app_shell.dart';
import '../theme/app_theme.dart';

class QuickNavBar extends StatelessWidget {
  const QuickNavBar({
    super.key,
    required this.onCartTap,
    this.cartCount = 0,
  });

  final VoidCallback onCartTap;
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: _NavButton(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  onTap: () => goToEmployeeHome(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NavButton(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Carrito',
                  onTap: onCartTap,
                  badgeCount: cartCount,
                  accent: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.accent : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: SizedBox(
          height: AppDecorations.tapMin,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (badgeCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent ? AppColors.onAccent : AppColors.accent,
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: AppText.code.copyWith(
                      color: accent ? AppColors.accent : AppColors.onAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(
                  icon,
                  size: 18,
                  color: accent ? AppColors.onAccent : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                  color: accent ? AppColors.onAccent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
