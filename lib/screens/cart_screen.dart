import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/uppercase_input.dart';
import '../widgets/added_to_cart_sheet.dart';
import '../widgets/feria_shell.dart';
import '../widgets/payment_method_dialog.dart';
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
    final pricing = PricingService();

    var totalUsd = 0.0;
    var totalArs = 0.0;
    var hasUsdPayments = false;
    var hasArsPayments = false;

    for (final item in cart.items) {
      final prices = pricing.pricesFor(
        item.product,
        exchangeRate,
        pricingSettings,
      );
      final lineUsd =
          prices.usd * item.quantity * item.paymentShare;
      final lineArs = item.paymentMethod.totalArsFor(prices) *
          item.quantity *
          item.paymentShare;

      if (item.paymentMethod.isUsdPayment) {
        hasUsdPayments = true;
        totalUsd += lineUsd;
      } else {
        hasArsPayments = true;
        totalArs += lineArs;
      }
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
                      final lineUsd =
                          prices.usd * item.quantity * item.paymentShare;
                      final lineArs = item.paymentMethod.totalArsFor(prices) *
                          item.quantity *
                          item.paymentShare;

                      return _CartItemCard(
                        item: item,
                        prices: prices,
                        lineUsd: lineUsd,
                        lineArs: lineArs,
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
                        onSerialChanged: item.product.isArma &&
                                (item.splitPart == null || item.splitPart == 1)
                            ? (value) => cart.updateSerialNumber(
                                  item.lineKey,
                                  value,
                                )
                            : null,
                        onPaymentTap: !item.isSplitPart
                            ? () async {
                                if (item.product.isArma) {
                                  final selected = await showWeaponPaymentDialog(
                                    context,
                                    product: item.product,
                                  );
                                  if (selected == null ||
                                      !context.mounted ||
                                      selected.isDual) {
                                    return;
                                  }
                                  context
                                      .read<CartService>()
                                      .updatePaymentMethod(
                                        item.lineKey,
                                        selected.first,
                                      );
                                  return;
                                }

                                final method = await showSinglePaymentDialog(
                                  context,
                                  product: item.product,
                                  current: item.paymentMethod,
                                );
                                if (method == null || !context.mounted) return;

                                context.read<CartService>().updatePaymentMethod(
                                      item.lineKey,
                                      method,
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
              hasUsdPayments: hasUsdPayments,
              hasArsPayments: hasArsPayments,
              onOpenBudget: () => _openBudget(context),
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
    required this.prices,
    required this.lineUsd,
    required this.lineArs,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    this.onSerialChanged,
    this.onPaymentTap,
  });

  final CartItem item;
  final ProductPrices prices;
  final double lineUsd;
  final double lineArs;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String>? onSerialChanged;
  final VoidCallback? onPaymentTap;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final paysInUsd = item.paymentMethod.isUsdPayment;
    final primaryLabel = paysInUsd ? 'TOTAL USD' : 'TOTAL ARS';
    final primaryValue = paysInUsd ? formatUsd(lineUsd) : formatArs(lineArs);
    final referenceValue = paysInUsd
        ? 'Ref. lista: ${formatArs(prices.lista * item.quantity * item.paymentShare)}'
        : 'Catálogo: ${formatUsd(prices.usd * item.quantity * item.paymentShare)}';

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
          if (product.isArma) ...[
            const SizedBox(height: 4),
            Text(
              'Cal. ${product.calibre}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (item.isSplitPart) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Pago dividido ${item.splitPart}/2',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.goldDark,
                ),
              ),
            ),
          ],
          if (onSerialChanged != null) ...[
            const SizedBox(height: 10),
            _CartSerialField(
              initialValue: item.serialNumber,
              onChanged: onSerialChanged!,
            ),
          ],
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: AppDecorations.radiusSm,
              border: Border.all(color: AppColors.goldDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  primaryValue,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  referenceValue,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!item.isSplitPart)
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
  const _QtyButton({
    required this.icon,
    this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _CartTotalFooter extends StatelessWidget {
  const _CartTotalFooter({
    required this.totalUsd,
    required this.totalArs,
    required this.hasUsdPayments,
    required this.hasArsPayments,
    required this.onOpenBudget,
  });

  final double totalUsd;
  final double totalArs;
  final bool hasUsdPayments;
  final bool hasArsPayments;
  final VoidCallback onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final showBoth = hasUsdPayments && hasArsPayments;

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
          if (showBoth)
            Row(
              children: [
                Expanded(
                  child: _FooterTotalColumn(
                    label: 'TOTAL USD',
                    value: formatUsd(totalUsd),
                    valueColor: Colors.white,
                  ),
                ),
                Container(
                  width: 1,
                  height: 56,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _FooterTotalColumn(
                    label: 'TOTAL ARS',
                    value: formatArs(totalArs),
                    valueColor: AppColors.gold,
                  ),
                ),
              ],
            )
          else
            _FooterTotalColumn(
              label: hasUsdPayments ? 'TOTAL USD' : 'TOTAL ARS',
              value: hasUsdPayments ? formatUsd(totalUsd) : formatArs(totalArs),
              valueColor: hasUsdPayments ? Colors.white : AppColors.gold,
              centered: true,
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
                onPressed: onOpenBudget,
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

class _FooterTotalColumn extends StatelessWidget {
  const _FooterTotalColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.centered = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: valueColor,
              ),
        ),
      ],
    );
  }
}

class _CartSerialField extends StatefulWidget {
  const _CartSerialField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_CartSerialField> createState() => _CartSerialFieldState();
}

class _CartSerialFieldState extends State<_CartSerialField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_CartSerialField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text &&
        widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: UpperCaseTextFormatter.formatters,
      decoration: const InputDecoration(
        labelText: 'N° de serie',
        hintText: 'Completar al confirmar la venta',
        isDense: true,
      ),
    );
  }
}
