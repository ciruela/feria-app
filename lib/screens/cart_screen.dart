import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/employee/employee_cart_body.dart';
import '../widgets/employee/employee_nav.dart';
import 'auth/tenant_app_shell.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _exit(BuildContext context) {
    exitInTenantFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);
    final cartCount = context.watch<CartService>().itemCount;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 900),
                  child: const EmployeeCartBody(),
                ),
              )
            : const EmployeeCartBody(),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : EmployeeBottomNav(
              selected: EmployeeNavItem.cart,
              cartCount: cartCount,
              onCatalog: () => Navigator.of(context).pop(),
              onCart: () {},
              onExit: () => _exit(context),
            ),
    );
  }
}
