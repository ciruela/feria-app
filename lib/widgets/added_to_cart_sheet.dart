import 'package:flutter/material.dart';

import '../models/product.dart';
import '../screens/cart_screen.dart';
import '../theme/app_theme.dart';

enum AddedToCartAction { continueShopping, goToCart }

Future<AddedToCartAction?> showAddedToCartSheet(
  BuildContext context, {
  required String productLabel,
}) {
  return showModalBottomSheet<AddedToCartAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$productLabel agregado',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '¿Querés ir al carrito o seguir comprando?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        AddedToCartAction.continueShopping,
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('SEGUIR COMPRANDO'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        AddedToCartAction.goToCart,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('IR AL CARRITO'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> handleAddedToCartNavigation(
  BuildContext context,
  AddedToCartAction? action,
) async {
  if (action != AddedToCartAction.goToCart || !context.mounted) return;

  Navigator.of(context).pop();
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const CartScreen()),
  );
}

void showStockLimitMessage(BuildContext context, Product product) {
  final stock = product.stock;
  final message = stock == 1
      ? 'Solo hay 1 unidad disponible'
      : 'Stock máximo alcanzado (${stock ?? 0} unidades)';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
