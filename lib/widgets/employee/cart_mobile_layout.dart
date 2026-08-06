import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/payment_config.dart';
import '../../models/cart_checkout_payment.dart';
import '../../models/product_prices.dart';
import '../../screens/budget_screen.dart';
import '../../services/cart_service.dart';
import '../../services/cart_totals_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/pricing_service.dart';
import '../../services/pricing_settings_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../added_to_cart_sheet.dart';
import '../cart_checkout_payment_panel.dart';
import 'employee_cart_body.dart';

/// Mock 05_Mob — carrito con ítems.
class CartMobileLayout extends StatelessWidget {
  const CartMobileLayout({super.key});

  Future<void> _openBudget(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BudgetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final seller = context.watch<SellerService>().selected;
    final pricing = context.read<PricingService>();
    final totalsService = context.read<CartTotalsService>();
    final checkout = cart.checkoutPayment;
    final pricingMethod = checkout?.pricingMethod ?? defaultPaymentMethod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Carrito',
                style: AppText.heading.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cart.isEmpty
                    ? 'Todavía no cargaste nada'
                    : '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}'
                        '${seller != null ? ' · ${formatSellerFirstName(seller.nombre)}' : ''}',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Agregá productos desde el catálogo',
                      textAlign: TextAlign.center,
                      style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                )
              : _CartMobileContent(
                  cart: cart,
                  exchangeRate: exchangeRate,
                  pricingSettings: pricingSettings,
                  pricing: pricing,
                  totalsService: totalsService,
                  checkout: checkout,
                  pricingMethod: pricingMethod,
                  onContinue: checkout != null && exchangeRate.hasServerRate
                      ? () => _openBudget(context)
                      : null,
                ),
        ),
      ],
    );
  }
}

class _CartMobileContent extends StatelessWidget {
  const _CartMobileContent({
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.pricing,
    required this.totalsService,
    required this.checkout,
    required this.pricingMethod,
    required this.onContinue,
  });

  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final PricingService pricing;
  final CartTotalsService totalsService;
  final CartCheckoutPayment? checkout;
  final PaymentMethod pricingMethod;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    CartLineTotal? checkoutTotal;
    List<PaymentAllocation> allocations = [];
    if (checkout != null) {
      checkoutTotal = totalsService.cartTotalAtMethod(
        cart: cart,
        method: checkout!.pricingMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      allocations = totalsService.allocationsFor(
        checkout: checkout!,
        total: checkoutTotal,
      );
    }

    final hasRate = exchangeRate.hasServerRate;
    final listaTotal = hasRate
        ? totalsService.cartTotalAtMethod(
            cart: cart,
            method: PaymentMethod.lista,
            exchangeRate: exchangeRate,
            pricingSettings: pricingSettings,
          )
        : const CartLineTotal(usd: 0, ars: 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (!hasRate) ...[
          Material(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Falta el tipo de cambio de esta armería. '
                'Administración debe cargarlo antes de vender.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const CartCheckoutPaymentPanel(
          budgetHandoff: true,
          raisedSurface: true,
        ),
        const SizedBox(height: 12),
        _CartMobileCard(
          child: Column(
            children: [
              for (var i = 0; i < cart.items.length; i++) ...[
                if (i > 0) const Divider(color: AppColors.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _CartMobileLine(
                    item: cart.items[i],
                    lineUsd: _lineUsd(cart.items[i]),
                    lineArs: hasRate ? _lineArs(cart.items[i]) : 0,
                    showArs: hasRate,
                    canIncrease: _canIncrease(cart, cart.items[i]),
                    onDecrease: () =>
                        cart.changeQuantity(cart.items[i].lineKey, cart.items[i].quantity - 1),
                    onIncrease: () => _increase(context, cart, cart.items[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CartMobileCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: EmployeeCartTotalsBlock(
              totalUsd: checkoutTotal?.usd ??
                  (hasRate
                      ? listaTotal.usd
                      : cart.items.fold<double>(
                          0,
                          (s, i) => s + i.product.precioUsd * i.quantity,
                        )),
              listaArs: hasRate ? listaTotal.ars : 0,
              allocations: hasRate ? allocations : const [],
              checkoutConfigured: checkout != null,
              hasServerRate: hasRate,
              exchangeRate: hasRate ? exchangeRate.rate : null,
              updatedAt: hasRate ? exchangeRate.updatedAt : null,
              listaValueMuted: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onContinue,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            disabledBackgroundColor: AppColors.surfaceTouch,
            disabledForegroundColor: AppColors.textMuted,
            minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
          ),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Continuar al presupuesto'),
        ),
      ],
    );
  }

  double _lineUsd(CartItem item) {
    final prices = pricing.pricesFor(item.product, exchangeRate, pricingSettings);
    return prices.usd * item.quantity;
  }

  double _lineArs(CartItem item) {
    final prices = pricing.pricesFor(item.product, exchangeRate, pricingSettings);
    return pricingMethod.totalArsFor(prices) * item.quantity;
  }

  bool _canIncrease(CartService cart, CartItem item) {
    final max = cart.maxQuantityForLine(item);
    return max == null || item.quantity < max;
  }

  void _increase(BuildContext context, CartService cart, CartItem item) {
    final max = cart.maxQuantityForLine(item);
    if (max != null && item.quantity >= max) {
      showStockLimitMessage(context, item.product);
      return;
    }
    cart.changeQuantity(item.lineKey, item.quantity + 1);
  }
}

class _CartMobileCard extends StatelessWidget {
  const _CartMobileCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _CartMobileLine extends StatelessWidget {
  const _CartMobileLine({
    required this.item,
    required this.lineUsd,
    required this.lineArs,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    this.showArs = true,
  });

  final CartItem item;
  final double lineUsd;
  final double lineArs;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool showArs;

  @override
  Widget build(BuildContext context) {
    return EmployeeCartLine(
      item: item,
      lineUsd: lineUsd,
      lineArs: lineArs,
      showArs: showArs,
      canIncrease: canIncrease,
      onDecrease: onDecrease,
      onIncrease: onIncrease,
    );
  }
}
