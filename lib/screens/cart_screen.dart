import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
import '../models/cart_checkout_payment.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../widgets/cart/cart_item_card.dart';
import '../widgets/cart/cart_total_footer.dart';
import '../widgets/cart_checkout_payment_panel.dart';
import '../widgets/added_to_cart_sheet.dart';
import '../widgets/feria_shell.dart';
import '../widgets/quick_nav_bar.dart';
import '../widgets/section_header.dart';
import 'budget_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _openBudget(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BudgetScreen(),
      ),
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

    var totalUsd = 0.0;
    var totalArs = 0.0;
    var hasUsdPayments = false;
    var hasArsPayments = false;
    List<PaymentAllocation> paymentAllocations = [];

    if (checkout != null) {
      final cartTotal = totalsService.cartTotalAtMethod(
        cart: cart,
        method: checkout.pricingMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      paymentAllocations = totalsService.allocationsFor(
        checkout: checkout,
        total: cartTotal,
      );
      for (final allocation in paymentAllocations) {
        if (allocation.paysInUsd) {
          hasUsdPayments = true;
          totalUsd += allocation.amountUsd;
        } else {
          hasArsPayments = true;
          totalArs += allocation.amountArs;
        }
      }
    } else {
      final previewTotal = totalsService.cartTotalAtMethod(
        cart: cart,
        method: pricingMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      totalUsd = previewTotal.usd;
      totalArs = previewTotal.ars;
      hasUsdPayments = pricingMethod.isUsdPayment;
      hasArsPayments = !pricingMethod.isUsdPayment;
    }

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Carrito'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: cart.clear,
              child: const Text(
                'VACIAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (seller != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: InfoBanner(
                text: 'Vendedor: ${seller.nombre}',
                icon: Icons.support_agent_rounded,
              ),
            ),
          Expanded(
            child: cart.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Carrito vacío',
                    subtitle: 'Agregá productos desde el catálogo',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const CartCheckoutPaymentPanel();
                      }

                      final item = cart.items[index - 1];
                      final prices = pricing.pricesFor(
                        item.product,
                        exchangeRate,
                        pricingSettings,
                      );
                      final lineUsd = prices.usd * item.quantity;
                      final lineArs =
                          pricingMethod.totalArsFor(prices) * item.quantity;

                      return CartItemCard(
                        item: item,
                        prices: prices,
                        lineUsd: lineUsd,
                        lineArs: lineArs,
                        displayMethod: pricingMethod,
                        canIncrease: () {
                          final max = cart.maxQuantityForLine(item);
                          return max == null || item.quantity < max;
                        }(),
                        onDecrease: () => cart.changeQuantity(
                          item.lineKey,
                          item.quantity - 1,
                        ),
                        onIncrease: () {
                          final max = cart.maxQuantityForLine(item);
                          if (max != null && item.quantity >= max) {
                            showStockLimitMessage(context, item.product);
                            return;
                          }
                          cart.changeQuantity(
                            item.lineKey,
                            item.quantity + 1,
                          );
                        },
                        onSerialChanged: item.product.isArma
                            ? (value) => cart.updateSerialNumber(
                                  item.lineKey,
                                  value,
                                )
                            : null,
                      );
                    },
                  ),
          ),
          if (!cart.isEmpty)
            CartTotalFooter(
              totalUsd: totalUsd,
              totalArs: totalArs,
              hasUsdPayments: hasUsdPayments,
              hasArsPayments: hasArsPayments,
              paymentAllocations: paymentAllocations,
              checkoutConfigured: checkout != null,
              onOpenBudget:
                  checkout != null ? () => _openBudget(context) : null,
            ),
        ],
      ),
      bottomNavigationBar: QuickNavBar(
        cartCount: cart.itemCount,
        onCartTap: () {},
      ),
    );
  }
}
