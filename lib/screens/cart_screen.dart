import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/employee/cart_mobile_layout.dart';
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
      backgroundColor: isDesktop ? AppColors.surface : AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: isDesktop
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520, maxHeight: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AR-38: full-screen cart (reached from product detail /
                      // "added to cart") had no back control on desktop.
                      if (Navigator.of(context).canPop())
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.chevron_left_rounded, size: 20),
                              label: const Text('Volver al catálogo'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      const Expanded(child: EmployeeCartBody()),
                    ],
                  ),
                ),
              )
            : const CartMobileLayout(),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : EmployeeBottomNav(
              selected: EmployeeNavItem.cart,
              cartCount: cartCount,
              onCatalog: () => Navigator.of(context).maybePop(),
              onCart: () {},
              onExit: () => _exit(context),
            ),
    );
  }
}
