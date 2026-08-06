import 'package:flutter/material.dart';

import '../../screens/auth/tenant_app_shell.dart';
import '../../theme/app_theme.dart';
import '../armenext_brand.dart';

enum EmployeeNavItem { catalog, byCode, adminProducts, adminExchange, cart, exit }

class EmployeeSidebar extends StatelessWidget {
  const EmployeeSidebar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showAdminSection = true,
  });

  final EmployeeNavItem selected;
  final ValueChanged<EmployeeNavItem> onSelected;
  final bool showAdminSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          right: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: ArmenextMonogram(size: 32),
          ),
          const _SectionLabel('OPERACIÓN'),
          _NavTile(
            label: 'Catálogo',
            icon: Icons.search_rounded,
            selected: selected == EmployeeNavItem.catalog,
            onTap: () => onSelected(EmployeeNavItem.catalog),
          ),
          _NavTile(
            label: 'Por código',
            icon: Icons.qr_code_2_outlined,
            selected: selected == EmployeeNavItem.byCode,
            onTap: () => onSelected(EmployeeNavItem.byCode),
          ),
          if (showAdminSection) ...[
            const SizedBox(height: 16),
            const _SectionLabel('ADMINISTRACIÓN'),
            _NavTile(
              label: 'Productos',
              icon: Icons.inventory_2_outlined,
              selected: selected == EmployeeNavItem.adminProducts,
              onTap: () => onSelected(EmployeeNavItem.adminProducts),
            ),
            _NavTile(
              label: 'Tipo de cambio',
              icon: Icons.currency_exchange_rounded,
              selected: selected == EmployeeNavItem.adminExchange,
              onTap: () => onSelected(EmployeeNavItem.adminExchange),
            ),
          ],
          const Spacer(),
          _NavTile(
            label: 'Salir',
            icon: Icons.logout_rounded,
            selected: false,
            onTap: () => onSelected(EmployeeNavItem.exit),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        label,
        style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    left: BorderSide(color: AppColors.textPrimary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppText.bodyLarge.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeBottomNav extends StatelessWidget {
  const EmployeeBottomNav({
    super.key,
    required this.selected,
    required this.cartCount,
    required this.onCatalog,
    required this.onCart,
    required this.onExit,
  });

  final EmployeeNavItem selected;
  final int cartCount;
  final VoidCallback onCatalog;
  final VoidCallback onCart;
  final VoidCallback onExit;

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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  icon: Icons.search_rounded,
                  label: 'Catálogo',
                  selected: selected == EmployeeNavItem.catalog ||
                      selected == EmployeeNavItem.byCode,
                  onTap: onCatalog,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Carrito',
                  selected: selected == EmployeeNavItem.cart,
                  badge: cartCount,
                  onTap: onCart,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  icon: Icons.tune_rounded,
                  label: 'Salir',
                  selected: false,
                  onTap: onExit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(AppDecorations.radius),
                      ),
                      child: Text(
                        '$badge',
                        style: AppText.code.copyWith(
                          color: AppColors.onAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: AppText.label.copyWith(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

void handleEmployeeNavExit(BuildContext context) {
  exitInTenantFlow(context);
}
