import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_checkout_payment.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'cart_checkout_payment_dialog.dart';

class CartCheckoutPaymentPanel extends StatelessWidget {
  const CartCheckoutPaymentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    if (cart.isEmpty) return const SizedBox.shrink();

    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();
    final checkout = cart.checkoutPayment;

    return Material(
      color: AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: () async {
          final selected = await showCartCheckoutPaymentDialog(
            context,
            current: checkout,
          );
          if (selected == null || !context.mounted) return;
          context.read<CartService>().setCheckoutPayment(selected);
        },
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'CÓMO ABONA EL CLIENTE',
                      style: AppText.label,
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 8),
              if (checkout == null)
                const Text(
                  'Definí una o dos formas de pago para toda la venta.',
                  style: AppText.bodySmall,
                )
              else
                _CheckoutSummary(
                  checkout: checkout,
                  cart: cart,
                  exchangeRate: exchangeRate,
                  pricingSettings: pricingSettings,
                  totalsService: totalsService,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.checkout,
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
  });

  final CartCheckoutPayment checkout;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;

  @override
  Widget build(BuildContext context) {
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

    if (allocations.length == 1) {
      final allocation = allocations.first;
      final amount = allocation.paysInUsd
          ? formatUsd(allocation.amountUsd)
          : formatArs(allocation.amountArs);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allocation.method.shortLabel,
            style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(amount, style: AppText.number.copyWith(fontSize: 20)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allocations.map((allocation) {
        final amount = allocation.paysInUsd
            ? formatUsd(allocation.amountUsd)
            : formatArs(allocation.amountArs);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  allocation.method.shortLabel,
                  style: AppText.bodySmall,
                ),
              ),
              Text(amount, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
