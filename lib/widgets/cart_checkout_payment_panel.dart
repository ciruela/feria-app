import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../models/cart_checkout_payment.dart';
import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'cart_checkout_payment_dialog.dart';

class CartCheckoutPaymentPanel extends StatelessWidget {
  const CartCheckoutPaymentPanel({
    super.key,
    this.budgetHandoff = false,
    this.raisedSurface = false,
  });

  /// Mock 07_Desk / 05_Mob: método y monto en una fila horizontal.
  final bool budgetHandoff;

  /// Mock 05_Mob: fondo elevado en lugar de touch.
  final bool raisedSurface;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    if (cart.isEmpty) return const SizedBox.shrink();

    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();
    final checkout = cart.checkoutPayment;
    final hasPerLineMethods =
        cart.items.any((item) => item.paymentMethod != null);

    return Material(
      color: raisedSurface ? AppColors.surfaceRaised : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: () async {
          await showCartCheckoutPaymentDialog(
            context,
            current: checkout,
          );
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CÓMO ABONA EL CLIENTE',
                      style: AppText.label.copyWith(fontSize: 10),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 8),
              if (checkout == null && !hasPerLineMethods)
                const Text(
                  'Elegí el medio de pago general de la venta. '
                  'Podés ajustar productos puntuales desde su renglón.',
                  style: AppText.bodySmall,
                )
              else
                _CheckoutSummary(
                  checkout: checkout,
                  cart: cart,
                  exchangeRate: exchangeRate,
                  pricingSettings: pricingSettings,
                  totalsService: totalsService,
                  budgetHandoff: budgetHandoff,
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
    this.budgetHandoff = false,
  });

  final CartCheckoutPayment? checkout;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final bool budgetHandoff;

  @override
  Widget build(BuildContext context) {
    final listaTotal = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.lista,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );

    // Si hay medios por renglón, el resumen debe reflejar lo que realmente
    // paga el cliente (mezcla de métodos), no el total al método global.
    final hasPerLineMethods =
        cart.items.any((item) => item.paymentMethod != null);

    final List<PaymentAllocation> allocations;
    final String? deltaLabel;
    if (hasPerLineMethods) {
      allocations = totalsService.allocationsForCart(
        cart: cart,
        fallbackMethod: checkout?.pricingMethod ?? defaultPaymentMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      final rate = exchangeRate.rate;
      final pricedArs = allocations.fold<double>(
        0,
        (sum, a) => sum + (a.paysInUsd ? a.amountUsd * rate : a.amountArs),
      );
      deltaLabel = formatSignedArsDelta(pricedArs - listaTotal.ars);
    } else {
      // Sin medios por renglón siempre hay checkout global (el panel no llama
      // a este resumen si ambos faltan).
      final method = checkout!.pricingMethod;
      final total = totalsService.cartTotalAtMethod(
        cart: cart,
        method: method,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      allocations = totalsService.allocationsFor(
        checkout: checkout!,
        total: total,
      );
      deltaLabel = method.isUsdPayment
          ? formatSignedUsdDelta(total.usd - listaTotal.usd)
          : formatSignedArsDelta(total.ars - listaTotal.ars);
    }

    if (allocations.length == 1) {
      final allocation = allocations.first;
      final amount = allocation.paysInUsd
          ? formatUsd(allocation.amountUsd)
          : formatArs(allocation.amountArs);

      if (budgetHandoff) {
        return Row(
          children: [
            Expanded(
              child: Text(
                allocation.method.shortLabel,
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
                if (deltaLabel != null)
                  Text(
                    deltaLabel,
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allocation.method.shortLabel,
            style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: AppText.number.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (deltaLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              deltaLabel,
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...allocations.map((allocation) {
          final amount = allocation.paysInUsd
              ? formatUsd(allocation.amountUsd)
              : formatArs(allocation.amountArs);
          final cuotas = allocation.method.installments;
          final detail = (!allocation.paysInUsd && cuotas != null && cuotas > 1)
              ? '$cuotas x ${formatArs(allocation.amountArs / cuotas)}'
              : null;
          final lineDelta = formatSignedArsDelta(allocation.deltaArs);
          final sub = [
            if (detail != null) detail,
            if (lineDelta != null) lineDelta,
          ].join(' · ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allocation.method.shortLabel,
                        style: AppText.bodySmall,
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: AppText.bodySmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  amount,
                  style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }),
        if (deltaLabel != null)
          Text(
            'vs lista $deltaLabel',
            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }
}
