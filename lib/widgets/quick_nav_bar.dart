import 'package:flutter/material.dart';

import '../screens/employee/employee_home_screen.dart';
import '../theme/app_theme.dart';

void goToEmployeeHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
    (route) => false,
  );
}

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
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => goToEmployeeHome(context),
                  icon: const Icon(Icons.home, size: 28),
                  label: const Text('INICIO'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCartTap,
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    label: Text('$cartCount'),
                    child: const Icon(Icons.shopping_cart, size: 28),
                  ),
                  label: const Text('CARRITO'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
