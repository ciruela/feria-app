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

/// Cuerpo compartido del carrito (panel desktop, pantalla mobile y web).
class EmployeeCartBody extends StatelessWidget {
  const EmployeeCartBody({
    super.key,
    this.compact = false,
    this.showHeader = true,
    this.onContinueToBudget,
  });

  final bool compact;
  final bool showHeader;
  final VoidCallback? onContinueToBudget;

  Future<void> _openBudget(BuildContext context) async {
    if (onContinueToBudget != null) {
      onContinueToBudget!();
      return;
    }
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

    if (cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            compact
                ? 'El carrito está vacío.\nTocá un producto de la tabla para sumarlo.'
                : 'Agregá productos desde el catálogo',
            textAlign: TextAlign.center,
            style: AppText.bodySmall,
          ),
        ),
      );
    }

    CartLineTotal? checkoutTotal;
    List<PaymentAllocation> allocations = [];
    if (checkout != null) {
      checkoutTotal = totalsService.cartTotalAtMethod(
        cart: cart,
        method: checkout.pricingMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
      allocations = totalsService.allocationsFor(
        checkout: checkout,
        total: checkoutTotal,
      );
    }

    final listaTotal = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.lista,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, compact ? 16 : 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Carrito',
                  style: AppText.heading.copyWith(fontSize: compact ? 20 : 26),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cart.itemCount} ítem${cart.itemCount == 1 ? '' : 's'}'
                  '${seller != null ? ' · ${formatSellerFirstName(seller.nombre)}' : ''}',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
        ] else if (compact) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${cart.itemCount} ítem${cart.itemCount == 1 ? '' : 's'}'
              '${seller != null ? ' · ${formatSellerFirstName(seller.nombre)}' : ''}',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          child: const CartCheckoutPaymentPanel(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 4, compact ? 12 : 16, 8),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              final prices = pricing.pricesFor(
                item.product,
                exchangeRate,
                pricingSettings,
              );
              final lineUsd = prices.usd * item.quantity;
              final lineArs = pricingMethod.totalArsFor(prices) * item.quantity;

              return EmployeeCartLine(
                item: item,
                lineUsd: lineUsd,
                lineArs: lineArs,
                paysInUsd: pricingMethod.isUsdPayment,
                canIncrease: () {
                  final max = cart.maxQuantityForLine(item);
                  return max == null || item.quantity < max;
                }(),
                onDecrease: () => cart.changeQuantity(item.lineKey, item.quantity - 1),
                onIncrease: () {
                  final max = cart.maxQuantityForLine(item);
                  if (max != null && item.quantity >= max) {
                    showStockLimitMessage(context, item.product);
                    return;
                  }
                  cart.changeQuantity(item.lineKey, item.quantity + 1);
                },
              );
            },
          ),
        ),
        EmployeeCartFooter(
          compact: compact,
          totalUsd: checkoutTotal?.usd ?? listaTotal.usd,
          listaArs: listaTotal.ars,
          allocations: allocations,
          checkoutConfigured: checkout != null,
          exchangeRate: exchangeRate.rate,
          updatedAt: exchangeRate.updatedAt,
          onContinue: checkout != null ? () => _openBudget(context) : null,
        ),
      ],
    );
  }
}

class EmployeeCartLine extends StatelessWidget {
  const EmployeeCartLine({
    super.key,
    required this.item,
    required this.lineUsd,
    required this.lineArs,
    required this.paysInUsd,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final CartItem item;
  final double lineUsd;
  final double lineArs;
  final bool paysInUsd;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final title = product.isArma
        ? product.modeloDisplay.toUpperCase()
        : product.sellerShortTitle.toUpperCase();
    final code = product.codigo.isNotEmpty ? product.codigo : product.modeloDisplay;
    final unitUsd = lineUsd / item.quantity;
    final lineAmount = paysInUsd ? formatUsd(lineUsd) : formatArs(lineArs);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatUsd(unitUsd)} · $code',
                      style: AppText.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                lineAmount,
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyButton(icon: Icons.remove, onTap: onDecrease),
              SizedBox(
                width: 36,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: canIncrease ? onIncrease : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class EmployeeCartFooter extends StatelessWidget {
  const EmployeeCartFooter({
    super.key,
    required this.totalUsd,
    required this.listaArs,
    required this.allocations,
    required this.checkoutConfigured,
    required this.exchangeRate,
    this.updatedAt,
    this.onContinue,
    this.compact = false,
  });

  final double totalUsd;
  final double listaArs;
  final List<PaymentAllocation> allocations;
  final bool checkoutConfigured;
  final double? exchangeRate;
  final DateTime? updatedAt;
  final VoidCallback? onContinue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 12, compact ? 12 : 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!checkoutConfigured)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Configurá cómo abona el cliente para continuar',
                textAlign: TextAlign.center,
                style: AppText.bodySmall.copyWith(color: AppColors.accent),
              ),
            ),
          Text(
            'Total en dólares: ${formatUsd(totalUsd)}',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: 4),
          Text('Lista: ${formatArs(listaArs)}', style: AppText.bodySmall),
          if (allocations.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...allocations.map((allocation) {
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
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      amount,
                      style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (exchangeRate != null && updatedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Calculado con el dólar ${formatArs(exchangeRate!).replaceFirst(r'$ ', '')} · '
              '${formatDateTime(updatedAt!)}',
              style: AppText.bodySmall.copyWith(fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              disabledBackgroundColor: AppColors.surfaceTouch,
              minimumSize: Size.fromHeight(compact ? 44 : AppDecorations.buttonPrimary),
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Continuar al presupuesto'),
          ),
        ],
      ),
    );
  }
}
