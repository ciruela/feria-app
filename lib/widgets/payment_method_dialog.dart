import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_prices.dart';
import '../theme/app_theme.dart';
import 'filter_buttons.dart';

Future<PaymentMethod?> showPaymentMethodDialog(
  BuildContext context, {
  required Product product,
}) {
  return showDialog<PaymentMethod>(
    context: context,
    builder: (context) => _PaymentMethodDialog(product: product),
  );
}

class _PaymentMethodDialog extends StatelessWidget {
  const _PaymentMethodDialog({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final title = product.isArma ? product.modeloDisplay : product.codigo;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.goldDark,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text('¿Cómo abona el comprador?'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${product.marcaUpper} · $title',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...weaponPaymentMethods.map((method) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilterChipButton(
                  label: method.label.toUpperCase(),
                  selected: false,
                  onTap: () => Navigator.of(context).pop(method),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
      ],
    );
  }
}
