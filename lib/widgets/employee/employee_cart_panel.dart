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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Carrito',
              style: AppText.heading.copyWith(fontSize: 20),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Todavía no cargaste nada',
                          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppDecorations.radius),
                            border: Border.all(
                              color: AppColors.border,
                              width: AppDecorations.hairline,
                            ),
                          ),
                          child: const Text(
                            'El carrito está vacío.\n'
                            'Tocá un producto de la tabla para sumarlo.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySmall,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  )
                : const EmployeeCartBody(compact: true, showHeader: false),
          ),
        ],
      ),
    );
  }
}
