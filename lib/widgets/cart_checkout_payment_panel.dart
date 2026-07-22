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
      color: AppColors.surface,
      borderRadius: AppDecorations.radiusMd,
      child: InkWell(
        onTap: () async {
          final selected = await showCartCheckoutPaymentDialog(
            context,
            current: checkout,
          );
          if (selected == null || !context.mounted) return;
          context.read<CartService>().setCheckoutPayment(selected);
        },
        borderRadius: AppDecorations.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radiusMd,
            border: Border.all(
              color: checkout == null ? AppColors.goldDark : AppColors.border,
              width: checkout == null ? 1.5 : 1,
            ),
            boxShadow: checkout == null ? [AppDecorations.softShadow] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.goldDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      checkout == null
                          ? 'Configurar cómo abona el cliente'
                          : 'Cómo abona el cliente',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (checkout == null)
                const Text(
                  'Definí una o dos formas de pago para toda la venta. '
                  'Los montos se reflejan en el comprobante.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Precio de referencia: ${checkout.pricingMethod.label}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        ...allocations.map((allocation) {
          final amount = allocation.paysInUsd
              ? formatUsd(allocation.amountUsd)
              : formatArs(allocation.amountArs);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  allocation.paysInUsd
                      ? Icons.paid_rounded
                      : Icons.payments_outlined,
                  size: 18,
                  color: AppColors.goldDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allocation.method.label.toUpperCase(),
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
          );
        }),
      ],
    );
  }
}
