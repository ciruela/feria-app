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
import 'catalog_product_list.dart';

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

    final hasPerLineMethods =
        cart.items.any((item) => item.paymentMethod != null);
    CartLineTotal? checkoutTotal;
    List<PaymentAllocation> allocations = [];
    if (hasPerLineMethods) {
      // Cada producto con su medio: montos reales por método (no share global).
      allocations = totalsService.allocationsForCart(
        cart: cart,
        fallbackMethod: pricingMethod,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
    } else if (checkout != null) {
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

    final hasRate = exchangeRate.hasServerRate;
    final listaTotal = hasRate
        ? totalsService.cartTotalAtMethod(
            cart: cart,
            method: PaymentMethod.lista,
            exchangeRate: exchangeRate,
            pricingSettings: pricingSettings,
          )
        : const CartLineTotal(usd: 0, ars: 0);
    final canContinue = (checkout != null || hasPerLineMethods) && hasRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasRate)
          Material(
            color: AppColors.danger.withValues(alpha: 0.12),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        if (showHeader) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, compact ? 16 : 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Carrito',
                        style:
                            AppText.heading.copyWith(fontSize: compact ? 20 : 26),
                      ),
                    ),
                    const ClearCartButton(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}'
                  '${seller != null ? ' · ${formatSellerFirstName(seller.nombre)}' : ''}',
                  style: AppText.bodySmall,
                ),
              ],
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
              final effectiveMethod = item.paymentMethod ?? pricingMethod;
              final lineArs = hasRate
                  ? effectiveMethod.totalArsFor(prices) * item.quantity
                  : 0.0;

              final isArma = item.product.isArma;
              return EmployeeCartLine(
                item: item,
                prices: prices,
                globalMethod: pricingMethod,
                lineUsd: lineUsd,
                lineArs: lineArs,
                showArs: hasRate,
                canIncrease: isArma
                    ? cart.canAddMore(item.product)
                    : () {
                        final max = cart.maxQuantityForLine(item);
                        return max == null || item.quantity < max;
                      }(),
                // AR-33: − at qty 1 must not remove the line; use trash instead.
                onDecrease: isArma || item.quantity <= 1
                    ? null
                    : () => cart.changeQuantity(item.lineKey, item.quantity - 1),
                onIncrease: isArma
                    ? () {
                        // AR-41: + en arma agrega otra línea (otra serie), no qty.
                        if (!cart.canAddMore(item.product)) {
                          showStockLimitMessage(context, item.product);
                          return;
                        }
                        cart.addProduct(item.product);
                      }
                    : () {
                        final max = cart.maxQuantityForLine(item);
                        if (max != null && item.quantity >= max) {
                          showStockLimitMessage(context, item.product);
                          return;
                        }
                        cart.changeQuantity(item.lineKey, item.quantity + 1);
                      },
                onRemove: () => cart.removeLine(item.lineKey),
              );
            },
          ),
        ),
        EmployeeCartFooter(
          compact: compact,
          totalUsd: checkoutTotal?.usd ??
              (hasRate
                  ? listaTotal.usd
                  : cart.items.fold<double>(
                      0,
                      (s, i) => s + i.product.precioUsd * i.quantity,
                    )),
          listaArs: hasRate ? listaTotal.ars : 0,
          allocations: hasRate ? allocations : const [],
          checkoutConfigured: checkout != null || hasPerLineMethods,
          hasServerRate: hasRate,
          exchangeRate: hasRate ? exchangeRate.rate : null,
          updatedAt: hasRate ? exchangeRate.updatedAt : null,
          onContinue: canContinue ? () => _openBudget(context) : null,
        ),
      ],
    );
  }
}

/// Botón "Vaciar" que resetea carrito + forma de pago + datos del cliente
/// (nueva venta). Pensado para el header de cualquier superficie del carrito.
class ClearCartButton extends StatelessWidget {
  const ClearCartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => confirmClearCart(context),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Vaciar'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Pide confirmación y, si el usuario acepta, vacía el carrito y borra los
/// datos del cliente cargados. Acción destructiva: siempre confirmar.
Future<void> confirmClearCart(BuildContext context) async {
  final cart = context.read<CartService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      title: const Text('Vaciar carrito'),
      content: const Text(
        'Se van a borrar los productos, la forma de pago y los datos del '
        'cliente cargados. Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Vaciar'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    cart.clear();
  }
}

class EmployeeCartLine extends StatelessWidget {
  const EmployeeCartLine({
    super.key,
    required this.item,
    required this.lineUsd,
    required this.lineArs,
    required this.canIncrease,
    this.prices,
    this.globalMethod,
    this.onDecrease,
    this.onIncrease,
    this.onRemove,
    this.showArs = true,
  });

  final CartItem item;
  final double lineUsd;
  final double lineArs;
  final bool canIncrease;

  /// Precios del producto para poder ofrecer/mostrar el medio de pago por
  /// línea. Si es null (contexto sin cálculo), el chip no se muestra.
  final ProductPrices? prices;

  /// Medio de pago global del checkout (fallback cuando la línea no define uno).
  final PaymentMethod? globalMethod;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;
  final bool showArs;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final title = catalogProductTitle(product);
    final code = product.codigo.isNotEmpty ? product.codigo : product.modeloDisplay;
    final unitUsd = lineUsd / item.quantity;
    final isArma = product.isArma;
    final fallbackMethod = globalMethod ?? defaultPaymentMethod;
    final effectiveMethod = item.paymentMethod ?? fallbackMethod;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                showArs ? formatArs(lineArs) : '—',
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (prices != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _LinePaymentChip(
                method: effectiveMethod,
                usesGlobal: item.paymentMethod == null,
                onTap: () => _showLinePaymentPicker(
                  context,
                  item: item,
                  prices: prices!,
                  globalMethod: fallbackMethod,
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${formatUsd(unitUsd)} · $code',
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ),
              if (isArma) ...[
                // AR-41: qty fija 1; + agrega otra línea (otra serie).
                SizedBox(
                  width: 28,
                  child: Text(
                    '1',
                    textAlign: TextAlign.center,
                    style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: canIncrease ? onIncrease : null,
                ),
                const SizedBox(width: 4),
                _QtyButton(icon: Icons.delete_outline, onTap: onRemove),
              ] else ...[
                _QtyButton(icon: Icons.remove, onTap: onDecrease),
                SizedBox(
                  width: 28,
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
                const SizedBox(width: 4),
                _QtyButton(icon: Icons.delete_outline, onTap: onRemove),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Selector del medio de pago de UNA línea (promo + dos medios en un mismo
/// comprobante). Muestra el precio de cada método para este producto y permite
/// volver al "pago general" del checkout.
Future<void> _showLinePaymentPicker(
  BuildContext context, {
  required CartItem item,
  required ProductPrices prices,
  required PaymentMethod globalMethod,
}) async {
  final cart = context.read<CartService>();
  final qty = item.quantity;
  final usdAvailable = prices.usd > 0;
  final methods = weaponPaymentMethods.where((method) {
    if (method.isUsdPayment) return usdAvailable;
    return method.totalArsFor(prices) > 0;
  }).toList();

  String amountFor(PaymentMethod method) => method.isUsdPayment
      ? formatUsd(method.totalUsdFor(prices) * qty)
      : formatArs(method.totalArsFor(prices) * qty);

  // Subtítulo por opción: desglose de cuota + ahorro/recargo vs lista (ARS).
  String? subtitleFor(PaymentMethod method) {
    if (method.isUsdPayment) return null;
    final total = method.totalArsFor(prices) * qty;
    if (total <= 0) return null;
    final parts = <String>[];
    final n = method.installments;
    if (n != null && n > 1) parts.add('$n x ${formatArs(total / n)}');
    final delta = formatSignedArsDelta(total - prices.lista * qty);
    if (delta != null) parts.add(delta);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.canvas,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDecorations.radiusSheet),
      ),
    ),
    builder: (sheetContext) {
      final selected = item.paymentMethod;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Medio de pago de este producto',
                  style: AppText.heading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  catalogProductTitle(item.product),
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _LinePaymentOption(
                        label: 'Usar pago general',
                        trailing: globalMethod.shortLabel,
                        selected: selected == null,
                        onTap: () {
                          cart.setLinePaymentMethod(item.lineKey, null);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                      const Divider(color: AppColors.border, height: 16),
                      for (final method in methods) ...[
                        _LinePaymentOption(
                          label: method.shortLabel,
                          trailing: amountFor(method),
                          subtitle: subtitleFor(method),
                          selected: selected == method,
                          onTap: () {
                            cart.setLinePaymentMethod(item.lineKey, method);
                            Navigator.of(sheetContext).pop();
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _LinePaymentChip extends StatelessWidget {
  const _LinePaymentChip({
    required this.method,
    required this.usesGlobal,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool usesGlobal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = usesGlobal ? AppColors.textMuted : AppColors.accent;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: color.withValues(alpha: 0.6)),
            color: usesGlobal
                ? AppColors.surfaceTouch
                : AppColors.accent.withValues(alpha: 0.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                method.shortLabel,
                style: AppText.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (usesGlobal)
                Text(
                  ' · general',
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              Icon(Icons.arrow_drop_down, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinePaymentOption extends StatelessWidget {
  const _LinePaymentOption({
    required this.label,
    required this.trailing,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  /// Detalle opcional bajo el nombre (ej: "3 x $53.475 · + $ 6.975").
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.canvas : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 18, color: AppColors.canvas),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.bodySmall.copyWith(
                          color: selected
                              ? AppColors.canvas.withValues(alpha: 0.75)
                              : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: AppText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
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
    this.hasServerRate = true,
    required this.exchangeRate,
    this.updatedAt,
    this.onContinue,
    this.compact = false,
  });

  final double totalUsd;
  final double listaArs;
  final List<PaymentAllocation> allocations;
  final bool checkoutConfigured;
  final bool hasServerRate;
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
          EmployeeCartTotalsBlock(
            totalUsd: totalUsd,
            listaArs: listaArs,
            allocations: allocations,
            checkoutConfigured: checkoutConfigured,
            hasServerRate: hasServerRate,
            exchangeRate: exchangeRate,
            updatedAt: updatedAt,
            showExchangeNote: !compact,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              disabledBackgroundColor: AppColors.surfaceTouch,
              disabledForegroundColor: AppColors.textMuted,
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

/// Totales del carrito (mock 05 desktop footer / 05 mobile card).
class EmployeeCartTotalsBlock extends StatelessWidget {
  const EmployeeCartTotalsBlock({
    super.key,
    required this.totalUsd,
    required this.listaArs,
    required this.allocations,
    required this.checkoutConfigured,
    this.hasServerRate = true,
    required this.exchangeRate,
    this.updatedAt,
    this.showExchangeNote = true,
    this.listaValueMuted = false,
  });

  final double totalUsd;
  final double listaArs;
  final List<PaymentAllocation> allocations;
  final bool checkoutConfigured;
  final bool hasServerRate;
  final double? exchangeRate;
  final DateTime? updatedAt;
  final bool showExchangeNote;
  final bool listaValueMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasServerRate)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Sin tipo de cambio: no se muestran precios en pesos',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.danger),
            ),
          )
        else if (!checkoutConfigured)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Configurá cómo abona el cliente para continuar',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(color: AppColors.accent),
            ),
          ),
        _FooterTotalRow(
          label: 'Total en dólares',
          value: formatUsd(totalUsd),
        ),
        const SizedBox(height: 6),
        _FooterTotalRow(
          label: 'Lista',
          value: hasServerRate ? formatArs(listaArs) : '—',
          valueMuted: listaValueMuted || !hasServerRate,
        ),
        if (allocations.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...allocations.map((allocation) {
            final amount = allocation.paysInUsd
                ? formatUsd(allocation.amountUsd)
                : formatArs(allocation.amountArs);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _FooterTotalRow(
                label: allocation.method.shortLabel,
                value: amount,
                prominent: true,
              ),
            );
          }),
          // AR-39: delta of priced total (single or dual sum) vs lista.
          if (hasServerRate && allocations.any((a) => !a.paysInUsd)) ...[
            Builder(
              builder: (_) {
                final rate = exchangeRate ?? 0;
                // Convertimos la porción en USD a ARS para comparar contra lista
                // (si no, un pago por producto mixto ignora la línea en dólares).
                if (allocations.any((a) => a.paysInUsd) && rate <= 0) {
                  return const SizedBox.shrink();
                }
                final pricedArs = allocations.fold<double>(
                  0,
                  (sum, a) =>
                      sum + (a.paysInUsd ? a.amountUsd * rate : a.amountArs),
                );
                final deltaLabel = formatSignedArsDelta(pricedArs - listaArs);
                if (deltaLabel == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _FooterTotalRow(
                    label: 'vs lista',
                    value: deltaLabel,
                    valueMuted: true,
                  ),
                );
              },
            ),
          ],
        ],
        if (showExchangeNote && exchangeRate != null && updatedAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Calculado con el dólar ${formatArs(exchangeRate!).replaceFirst(r'$ ', '')} · '
            '${formatDateTime(updatedAt!)}',
            style: AppText.bodySmall.copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _FooterTotalRow extends StatelessWidget {
  const _FooterTotalRow({
    required this.label,
    required this.value,
    this.prominent = false,
    this.valueMuted = false,
  });

  final String label;
  final String value;
  final bool prominent;
  final bool valueMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            label,
            style: prominent
                ? AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)
                : AppText.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ),
        Text(
          value,
          style: prominent
              ? AppText.number.copyWith(fontSize: 22, fontWeight: FontWeight.w700)
              : AppText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueMuted ? AppColors.textMuted : AppColors.textPrimary,
                ),
        ),
      ],
    );
  }
}
