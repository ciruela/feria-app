import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'payment_method_dialog.dart';
import 'section_header.dart';

class BudgetPaymentPanel extends StatelessWidget {
  const BudgetPaymentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final pricing = PricingService();

    if (cart.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Formas de pago',
          subtitle: 'Revisá cómo abona el cliente antes de generar',
        ),
        const SizedBox(height: 12),
        ...cart.items.map((item) {
          final prices = pricing.pricesFor(
            item.product,
            exchangeRate,
            pricingSettings,
          );
          final lineUsd = prices.usd * item.quantity * item.paymentShare;
          final lineArs = item.paymentMethod.totalArsFor(prices) *
              item.quantity *
              item.paymentShare;
          final paysInUsd = item.paymentMethod.isUsdPayment;
          final amount =
              paysInUsd ? formatUsd(lineUsd) : formatArs(lineArs);
          final label = item.product.isArma
              ? item.product.modeloDisplay
              : item.product.codigo;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppColors.surface,
              borderRadius: AppDecorations.radiusMd,
              child: InkWell(
                onTap: item.isSplitPart
                    ? null
                    : () => _editPayment(context, item.product, item),
                borderRadius: AppDecorations.radiusMd,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: AppDecorations.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (item.isSplitPart) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Pago dividido ${item.splitPart}/2 · ${item.paymentMethod.shortLabel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            paysInUsd
                                ? Icons.paid_rounded
                                : Icons.account_balance_wallet_outlined,
                            size: 18,
                            color: AppColors.goldDark,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.paymentMethod.label.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            amount,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (!item.isSplitPart) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Tocá para cambiar la forma de pago',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _editPayment(
    BuildContext context,
    Product product,
    CartItem item,
  ) async {
    if (product.isArma) {
      final selection = await showWeaponPaymentDialog(context, product: product);
      if (selection == null || !context.mounted) return;

      if (selection.isDual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para pago dividido, volvé al carrito y agregá el producto de nuevo',
            ),
          ),
        );
        return;
      }

      context.read<CartService>().updatePaymentMethod(
            item.lineKey,
            selection.first,
          );
      return;
    }

    final method = await showSinglePaymentDialog(
      context,
      product: product,
      current: item.paymentMethod,
    );
    if (method == null || !context.mounted) return;

    context.read<CartService>().updatePaymentMethod(item.lineKey, method);
  }
}
