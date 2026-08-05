import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/employee/employee_cart_body.dart';

/// Panel lateral de carrito en catálogo desktop (diseño 05 desk).
class EmployeeCartPanel extends StatelessWidget {
  const EmployeeCartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(
          left: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
        ),
      ),
      child: cart.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'El carrito está vacío.\n'
                  'Tocá un producto de la tabla para sumarlo.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySmall,
                ),
              ),
            )
          : const EmployeeCartBody(compact: true, showHeader: true),
    );
  }
}
