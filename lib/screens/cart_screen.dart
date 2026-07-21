import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/invoice_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/buyer_name_dialog.dart';
import '../widgets/feria_shell.dart';
import '../widgets/payment_method_dialog.dart';
import '../widgets/quick_nav_bar.dart';
import '../widgets/section_header.dart';
import 'invoice_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _finalizeCart(BuildContext context) async {
    final buyerName = await showBuyerNameDialog(context);
    if (buyerName == null || !context.mounted) return;

    final cart = context.read<CartService>();
    final invoice = InvoiceService().buildFromCart(
      buyerFullName: buyerName,
      cart: cart,
      exchangeRate: context.read<ExchangeRateService>(),
      pricingSettings: context.read<PricingSettingsService>(),
      sellerService: context.read<SellerService>(),
    );

    cart.clear();

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(invoice: invoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final seller = context.watch<SellerService>().selected;
    final pricing = PricingService();

    var totalUsd = 0.0;
    var totalArs = 0.0;

    for (final item in cart.items) {
      final prices = pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      totalUsd += prices.usd * item.quantity;
      totalArs += item.paymentMethod.totalArsFor(prices) * item.quantity;
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
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final prices = pricing.pricesFor(
                        item.product,
                        exchangeRate,
                        pricingSettings,
                      );
                      final lineUsd = prices.usd * item.quantity;
                      final lineArs =
                          item.paymentMethod.totalArsFor(prices) * item.quantity;

                      return _CartItemCard(
                        item: item,
                        lineUsd: lineUsd,
                        lineArs: lineArs,
                        onDecrease: () => cart.changeQuantity(
                          item.lineKey,
                          item.quantity - 1,
                        ),
                        onIncrease: () => cart.changeQuantity(
                          item.lineKey,
                          item.quantity + 1,
                        ),
                        onPaymentTap: item.product.isArma
                            ? () async {
                                final selected = await showPaymentMethodDialog(
                                  context,
                                  product: item.product,
                                );
                                if (selected == null || !context.mounted) {
                                  return;
                                }
                                context.read<CartService>().updatePaymentMethod(
                                      item.lineKey,
                                      selected,
                                    );
                              }
                            : null,
                      );
                    },
                  ),
          ),
          if (!cart.isEmpty)
            _CartTotalFooter(
              totalUsd: totalUsd,
              totalArs: totalArs,
              onFinalize: () => _finalizeCart(context),
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

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.lineUsd,
    required this.lineArs,
    required this.onDecrease,
    required this.onIncrease,
    this.onPaymentTap,
  });

  final CartItem item;
  final double lineUsd;
  final double lineArs;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback? onPaymentTap;

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: [AppDecorations.softShadow],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.marcaUpper,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            product.isArma ? product.modeloDisplay : product.codigo,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Material(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPaymentTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.paymentMethod.isUsdPayment
                          ? Icons.paid_rounded
                          : Icons.account_balance_wallet_outlined,
                      size: 18,
                      color: AppColors.goldDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.paymentMethod.label.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (onPaymentTap != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AmountTile(
                  label: 'USD',
                  value: formatUsd(lineUsd),
                  highlight: item.paymentMethod.isUsdPayment,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountTile(
                  label: 'ARS',
                  value: formatArs(lineArs),
                  highlight: !item.paymentMethod.isUsdPayment,
                  subtitle: item.paymentMethod.isUsdPayment ? 'ref. lista' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onDecrease),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _QtyButton(icon: Icons.add, onTap: onIncrease),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.subtitle,
  });

  final String label;
  final String value;
  final bool highlight;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.surfaceMuted,
        borderRadius: AppDecorations.radiusSm,
        border: Border.all(
          color: highlight ? AppColors.goldDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _CartTotalFooter extends StatelessWidget {
  const _CartTotalFooter({
    required this.totalUsd,
    required this.totalArs,
    required this.onFinalize,
  });

  final double totalUsd;
  final double totalArs;
  final VoidCallback onFinalize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: AppDecorations.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'TOTAL USD',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatUsd(totalUsd),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 56,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'TOTAL ARS',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatArs(totalArs),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.gold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppDecorations.goldGradient,
                borderRadius: AppDecorations.radiusMd,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('GENERAR COMPROBANTE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
