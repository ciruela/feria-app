import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cart_checkout_payment.dart';
import '../models/presupuesto_branding.dart';
import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/tenant_session_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/layout_breakpoints.dart';
import 'employee/cart_checkout_payment_mobile.dart';

/// Medios de checkout del tenant; USD solo si WG/Urban y el carrito tiene USD.
List<PaymentMethod> _checkoutMethodsFor(
  BuildContext context, {
  required CartService cart,
  required ExchangeRateService exchangeRate,
  required PricingSettingsService pricingSettings,
  required CartTotalsService totalsService,
}) {
  final branding = PresupuestoBranding.forTenant(
    slug: context.read<TenantSessionService>().activeTenantSlug,
  );
  final tenantAllowsUsd = branding.isWorldGuns || branding.isUrban;
  final includeUsd = tenantAllowsUsd &&
      totalsService.cartSupportsUsdCheckout(
        cart: cart,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
      );
  return checkoutPaymentMethods(includeUsd: includeUsd);
}

Future<CartCheckoutPayment?> showCartCheckoutPaymentDialog(
  BuildContext context, {
  CartCheckoutPayment? current,
}) async {
  final cart = context.read<CartService>();
  final original = current ?? cart.checkoutPayment;
  final width = MediaQuery.sizeOf(context).width;
  final useSheet = !LayoutBreakpoints.isDesktop(width);

  final CartCheckoutPayment? result;

  if (useSheet) {
    result = await showModalBottomSheet<CartCheckoutPayment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      barrierColor: AppColors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDecorations.radiusSheet),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (_, scrollController) => _CartCheckoutPaymentDialog(
            current: current,
            scrollController: scrollController,
            asSheet: true,
          ),
        ),
      ),
    );
  } else {
    result = await showDialog<CartCheckoutPayment>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (context) => _CartCheckoutPaymentDialog(current: current),
    );
  }

  if (!context.mounted) return result;

  if (result != null) {
    cart.setCheckoutPayment(result);
  } else if (original != null) {
    cart.setCheckoutPayment(original);
  } else {
    cart.clearCheckoutPayment();
  }

  return result;
}

class _CartCheckoutPaymentDialog extends StatefulWidget {
  const _CartCheckoutPaymentDialog({
    this.current,
    this.scrollController,
    this.asSheet = false,
  });

  final CartCheckoutPayment? current;
  final ScrollController? scrollController;
  final bool asSheet;

  @override
  State<_CartCheckoutPaymentDialog> createState() =>
      _CartCheckoutPaymentDialogState();
}

class _CartCheckoutPaymentDialogState extends State<_CartCheckoutPaymentDialog> {
  CartCheckoutPayment? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  void _selectSingle(PaymentMethod method) {
    final payment = CartCheckoutPayment.single(method);
    setState(() => _selected = payment);
    context.read<CartService>().setCheckoutPayment(payment);
  }

  void _confirm() {
    Navigator.of(context).pop(_selected);
  }

  bool get _isSingleSelected {
    final selected = _selected;
    return selected != null && !selected.isDual;
  }

  PaymentMethod? get _selectedMethod =>
      _isSingleSelected ? _selected!.pricingMethod : null;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();

    final content = _buildContent(
      context,
      cart,
      exchangeRate,
      pricingSettings,
      totalsService,
    );

    if (widget.asSheet) return content;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusSheet),
        side: const BorderSide(
          color: AppColors.border,
          width: AppDecorations.hairline,
        ),
      ),
      child: content,
    );
  }

  Widget _buildContent(
    BuildContext context,
    CartService cart,
    ExchangeRateService exchangeRate,
    PricingSettingsService pricingSettings,
    CartTotalsService totalsService,
  ) {
    final methods = _checkoutMethodsFor(
      context,
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
      totalsService: totalsService,
    );

    if (widget.asSheet) {
      return CartCheckoutPaymentMobileContent(
        selected: _selected,
        selectedMethod: _selectedMethod,
        cart: cart,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
        totalsService: totalsService,
        methods: methods,
        scrollController: widget.scrollController,
        onSelectSingle: _selectSingle,
        onConfirm: _confirm,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.asSheet ? double.infinity : 680,
        maxHeight: widget.asSheet
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.84,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              children: [
                Text(
                  '¿Cómo abona el cliente?',
                  textAlign: TextAlign.center,
                  style: AppText.heading.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Es el medio general de la venta. Si un producto abona '
                  'distinto, cambiá su medio desde el chip en cada renglón '
                  'del carrito.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shrinkWrap: true,
              children: [
                for (final method in methods) ...[
                  _PaymentMethodRow(
                    method: method,
                    total: totalsService.cartTotalAtMethod(
                      cart: cart,
                      method: method,
                      exchangeRate: exchangeRate,
                      pricingSettings: pricingSettings,
                    ),
                    listaTotal: totalsService.cartTotalAtMethod(
                      cart: cart,
                      method: PaymentMethod.lista,
                      exchangeRate: exchangeRate,
                      pricingSettings: pricingSettings,
                    ),
                    selected: _selectedMethod == method,
                    onTap: () => _selectSingle(method),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected != null ? _confirm : null,
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

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
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
    final labelStyle = AppText.bodyLarge.copyWith(
      fontWeight: FontWeight.w600,
      color: selected ? AppColors.canvas : AppColors.textPrimary,
    );
    final amountStyle = AppText.bodyLarge.copyWith(
      fontWeight: FontWeight.w700,
      color: selected ? AppColors.canvas : AppColors.textPrimary,
    );
    final deltaStyle = AppText.bodySmall.copyWith(
      color: selected
          ? AppColors.canvas.withValues(alpha: 0.75)
          : AppColors.textMuted,
    );

    Widget label;
    if (installments != null && installments > 1 && !method.isUsdPayment) {
      final cuota = total.ars / installments;
      label = Text(
        '${method.shortLabel}: $installments x ${formatArs(cuota)}',
        style: labelStyle,
      );
    } else {
      label = Text(method.shortLabel, style: labelStyle);
    }

    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(child: label),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(amount, style: amountStyle),
                  if (deltaLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(deltaLabel, style: deltaStyle),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
