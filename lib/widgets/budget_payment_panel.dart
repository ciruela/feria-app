import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'cart_checkout_payment_dialog.dart';
import 'cart_checkout_payment_panel.dart';
import 'section_header.dart';

class BudgetPaymentPanel extends StatelessWidget {
  const BudgetPaymentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    if (cart.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Forma de pago',
          subtitle: 'Cómo abona el cliente en esta venta',
        ),
        const SizedBox(height: 12),
        const CartCheckoutPaymentPanel(),
        if (cart.checkoutPayment?.isDual ?? false) ...[
          const SizedBox(height: 12),
          _DualPaymentReminder(cart: cart),
        ],
      ],
    );
  }
}

class _DualPaymentReminder extends StatelessWidget {
  const _DualPaymentReminder({required this.cart});

  final CartService cart;

  @override
  Widget build(BuildContext context) {
    final checkout = cart.checkoutPayment!;
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();
    final total = totalsService.cartTotalAtMethod(
      cart: cart,
      method: checkout.pricingMethod,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );
    final allocations = totalsService.allocationsFor(
      checkout: checkout,
      total: total,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de cobro en el comprobante',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...allocations.map((allocation) {
            final amount = allocation.paysInUsd
                ? formatUsd(allocation.amountUsd)
                : formatArs(allocation.amountArs);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${allocation.method.label}: $amount',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final selected = await showCartCheckoutPaymentDialog(
                context,
                current: checkout,
              );
              if (selected == null || !context.mounted) return;
              context.read<CartService>().setCheckoutPayment(selected);
            },
            child: const Text('MODIFICAR FORMA DE PAGO'),
          ),
        ],
      ),
    );
  }
}
