import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cart_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/employee/employee_cart_body.dart';
import 'handoff_dashed_border.dart';

/// Panel lateral de carrito — mock 03_Desk / 05_Desk.
class EmployeeCartPanel extends StatelessWidget {
  const EmployeeCartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final seller = context.watch<SellerService>().selected;
    final sellerName =
        seller != null ? formatSellerFirstName(seller.nombre) : null;

    return Container(
      width: 320,
      color: AppColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carrito',
                  style: AppText.heading.copyWith(fontSize: 20),
                ),
                if (cart.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Todavía no cargaste nada',
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}'
                    '${sellerName != null ? ' · $sellerName' : ''}',
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: cart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: HandoffDashedBorder(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 48,
                        ),
                        child: Text(
                          'El carrito está vacío.\n'
                          'Tocá un producto de la tabla para sumarlo.',
                          textAlign: TextAlign.center,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  )
                : const EmployeeCartBody(compact: true, showHeader: false),
          ),
        ],
      ),
    );
  }
}
