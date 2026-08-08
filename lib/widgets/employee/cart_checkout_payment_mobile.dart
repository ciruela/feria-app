import 'package:flutter/material.dart';

import '../../models/cart_checkout_payment.dart';
import '../../models/product_prices.dart';
import '../../services/cart_service.dart';
import '../../services/cart_totals_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/pricing_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Mock 06_Mob — sheet de forma de pago en el carrito.
class CartCheckoutPaymentMobileContent extends StatelessWidget {
  const CartCheckoutPaymentMobileContent({
    super.key,
    required this.selected,
    required this.selectedMethod,
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
    required this.onSelectSingle,
    required this.onOpenDualPayment,
    required this.onConfirm,
    this.methods = checkoutDialogPaymentMethods,
    this.scrollController,
  });

  final CartCheckoutPayment? selected;
  final PaymentMethod? selectedMethod;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final ValueChanged<PaymentMethod> onSelectSingle;
  final VoidCallback onOpenDualPayment;
  final VoidCallback onConfirm;
  final List<PaymentMethod> methods;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              Text(
                '¿Cómo abona el cliente?',
                textAlign: TextAlign.center,
                style: AppText.heading.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define el precio de referencia del comprobante. '
                'Si hace falta, dividí el cobro en dos formas y repartí '
                'el monto de lista entre ambas.',
                textAlign: TextAlign.center,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDualPayment,
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Pagar en dos formas'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _PaymentMethodListCard(
                methods: methods,
                selectedMethod: selectedMethod,
                cart: cart,
                exchangeRate: exchangeRate,
                pricingSettings: pricingSettings,
                totalsService: totalsService,
                onSelect: onSelectSingle,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selected != null ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surfaceTouch,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.surfaceTouch,
                disabledForegroundColor: AppColors.textMuted,
                minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
              ),
              child: const Text('Listo'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodListCard extends StatelessWidget {
  const _PaymentMethodListCard({
    required this.methods,
    required this.selectedMethod,
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
    required this.onSelect,
  });

  final List<PaymentMethod> methods;
  final PaymentMethod? selectedMethod;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final ValueChanged<PaymentMethod> onSelect;

  @override
  Widget build(BuildContext context) {
    final listaTotal = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.lista,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDecorations.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < methods.length; i++) ...[
            if (i > 0) const Divider(color: AppColors.border, height: 1),
            CartCheckoutPaymentMobileRow(
              method: methods[i],
              total: totalsService.cartTotalAtMethod(
                cart: cart,
                method: methods[i],
                exchangeRate: exchangeRate,
                pricingSettings: pricingSettings,
              ),
              listaTotal: listaTotal,
              selected: selectedMethod == methods[i],
              onTap: () => onSelect(methods[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class CartCheckoutPaymentMobileRow extends StatelessWidget {
  const CartCheckoutPaymentMobileRow({
    super.key,
    required this.method,
    required this.total,
    required this.listaTotal,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final CartLineTotal total;
  final CartLineTotal listaTotal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount =
        method.isUsdPayment ? formatUsd(total.usd) : formatArs(total.ars);
    final deltaLabel = method.isUsdPayment
        ? formatSignedUsdDelta(total.usd - listaTotal.usd)
        : formatSignedArsDelta(total.ars - listaTotal.ars);
    final installments = _installmentCount(method);
    final fg = selected ? AppColors.canvas : AppColors.textPrimary;
    final labelStyle = AppText.bodyLarge.copyWith(
      fontWeight: FontWeight.w600,
      color: fg,
    );
    final amountStyle = AppText.bodyLarge.copyWith(
      fontWeight: FontWeight.w700,
      color: fg,
    );
    final middleStyle = AppText.bodySmall.copyWith(
      color: selected ? AppColors.canvas.withValues(alpha: 0.75) : AppColors.textMuted,
    );
    final deltaStyle = AppText.bodySmall.copyWith(
      color: selected
          ? AppColors.canvas.withValues(alpha: 0.75)
          : AppColors.textMuted,
    );

    Widget amountColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount, style: amountStyle),
        if (deltaLabel != null) ...[
          const SizedBox(height: 2),
          Text(deltaLabel, style: deltaStyle),
        ],
      ],
    );

    return Material(
      color: selected ? AppColors.textPrimary : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: installments != null && installments > 1 && !method.isUsdPayment
              ? Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(method.shortLabel, style: labelStyle),
                    ),
                    Expanded(
                      child: Text(
                        '$installments x ${formatArs(total.ars / installments)}',
                        textAlign: TextAlign.center,
                        style: middleStyle,
                      ),
                    ),
                    amountColumn,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(method.shortLabel, style: labelStyle),
                    ),
                    amountColumn,
                  ],
                ),
        ),
      ),
    );
  }
}

int? _installmentCount(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.tarjeta3 => 3,
    PaymentMethod.tarjeta6 => 6,
    PaymentMethod.tarjeta9 => 9,
    PaymentMethod.tarjeta12 => 12,
    PaymentMethod.tarjeta18 => 18,
    _ => null,
  };
}
