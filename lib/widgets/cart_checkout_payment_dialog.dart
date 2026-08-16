import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/payment_config.dart';
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
  return checkoutPaymentMethods(
    includeUsd: includeUsd,
    // USD transferencia (distinto de USD billete) solo en World Guns.
    includeUsdTransfer: branding.isWorldGuns,
  );
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

  void _selectDual(CartCheckoutPayment dual) {
    setState(() => _selected = dual);
    context.read<CartService>().setCheckoutPayment(dual);
  }

  Future<void> _openDualPayment(
    BuildContext context, {
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    required CartTotalsService totalsService,
  }) async {
    final dual = widget.asSheet
        ? await showModalBottomSheet<CartCheckoutPayment>(
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
                initialChildSize: 0.88,
                minChildSize: 0.5,
                maxChildSize: 0.96,
                builder: (_, scrollController) =>
                    _CartDualPaymentWizardDialog(
                  cart: cart,
                  exchangeRate: exchangeRate,
                  pricingSettings: pricingSettings,
                  totalsService: totalsService,
                  asSheet: true,
                  scrollController: scrollController,
                ),
              ),
            ),
          )
        : await showDialog<CartCheckoutPayment>(
            context: context,
            barrierColor: AppColors.scrim,
            builder: (context) => _CartDualPaymentWizardDialog(
              cart: cart,
              exchangeRate: exchangeRate,
              pricingSettings: pricingSettings,
              totalsService: totalsService,
            ),
          );
    if (dual != null && mounted) {
      _selectDual(dual);
    }
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
        onOpenDualPayment: () => _openDualPayment(
          context,
          cart: cart,
          exchangeRate: exchangeRate,
          pricingSettings: pricingSettings,
          totalsService: totalsService,
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openDualPayment(
                  context,
                  cart: cart,
                  exchangeRate: exchangeRate,
                  pricingSettings: pricingSettings,
                  totalsService: totalsService,
                ),
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

enum _DualPaymentStep { first, second, split }

/// Asistente para dividir el cobro en dos formas de pago con un reparto (%).
/// El primer método define el precio de referencia del carrito; el resto queda
/// en el segundo. Persiste como [CartCheckoutPayment.dual].
class _CartDualPaymentWizardDialog extends StatefulWidget {
  const _CartDualPaymentWizardDialog({
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
    this.asSheet = false,
    this.scrollController,
  });

  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final bool asSheet;
  final ScrollController? scrollController;

  @override
  State<_CartDualPaymentWizardDialog> createState() =>
      _CartDualPaymentWizardDialogState();
}

class _CartDualPaymentWizardDialogState
    extends State<_CartDualPaymentWizardDialog> {
  _DualPaymentStep _step = _DualPaymentStep.first;
  PaymentMethod? _first;
  PaymentMethod? _second;
  double _share = 0.5;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _total {
    if (_first == null) return 0;
    final total = widget.totalsService.cartTotalAtMethod(
      cart: widget.cart,
      method: _first!,
      exchangeRate: widget.exchangeRate,
      pricingSettings: widget.pricingSettings,
    );
    return _first!.isUsdPayment ? total.usd : total.ars;
  }

  double _amountFor(double share) => _total * share;

  String _formatAmount(double amount) {
    if (_first == null) return '';
    return _first!.isUsdPayment ? formatUsd(amount) : formatArs(amount);
  }

  void _syncShareFromAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0 || _total <= 0) return;

    setState(() {
      _share = (amount / _total).clamp(dualPaymentMinShare, dualPaymentMaxShare);
    });
  }

  bool get _canProceed {
    return switch (_step) {
      _DualPaymentStep.first => _first != null,
      _DualPaymentStep.second => _second != null,
      _DualPaymentStep.split => true,
    };
  }

  String get _stepTitle {
    return switch (_step) {
      _DualPaymentStep.first => 'Primera forma de pago',
      _DualPaymentStep.second => 'Segunda forma de pago',
      _DualPaymentStep.split => 'Dividir el pago',
    };
  }

  String? get _stepSubtitle {
    return switch (_step) {
      _DualPaymentStep.first =>
        'Elegí la primera forma. Define el precio de referencia del carrito.',
      _DualPaymentStep.second =>
        'Elegí la segunda forma. Tiene que ser distinta a la primera.',
      _DualPaymentStep.split =>
        'Indicá cuánto paga con ${_first?.shortLabel ?? 'la primera'} '
        'y el resto queda en ${_second?.shortLabel ?? 'la segunda'}.',
    };
  }

  void _goBack() {
    setState(() {
      _step = switch (_step) {
        _DualPaymentStep.second => _DualPaymentStep.first,
        _DualPaymentStep.split => _DualPaymentStep.second,
        _DualPaymentStep.first => _DualPaymentStep.first,
      };
    });
  }

  void _goNext() {
    if (!_canProceed) return;

    if (_step == _DualPaymentStep.split) {
      if (_first == null || _second == null) return;
      Navigator.of(context).pop(
        CartCheckoutPayment.dual(
          pricingMethod: _first!,
          secondMethod: _second!,
          primaryShare: _share,
        ),
      );
      return;
    }

    setState(() {
      _step = _step == _DualPaymentStep.first
          ? _DualPaymentStep.second
          : _DualPaymentStep.split;
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
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
            padding: EdgeInsets.fromLTRB(24, widget.asSheet ? 24 : 28, 24, 0),
            child: Column(
              children: [
                Text(
                  _stepTitle,
                  textAlign: TextAlign.center,
                  style: AppText.heading.copyWith(fontSize: 22),
                ),
                if (_stepSubtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _stepSubtitle!,
                    textAlign: TextAlign.center,
                    style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: switch (_step) {
                _DualPaymentStep.first || _DualPaymentStep.second =>
                  _MethodPicker(
                    mobileHandoff: widget.asSheet,
                    exclude: _step == _DualPaymentStep.second && _first != null
                        ? {_first!}
                        : const {},
                    selected: _step == _DualPaymentStep.first ? _first : _second,
                    cart: widget.cart,
                    exchangeRate: widget.exchangeRate,
                    pricingSettings: widget.pricingSettings,
                    totalsService: widget.totalsService,
                    onSelected: (method) {
                      setState(() {
                        if (_step == _DualPaymentStep.first) {
                          _first = method;
                        } else {
                          _second = method;
                        }
                      });
                    },
                  ),
                _DualPaymentStep.split => _SplitStep(
                    first: _first!,
                    second: _second!,
                    share: _share,
                    total: _total,
                    amountController: _amountController,
                    formatAmount: _formatAmount,
                    amountFor: _amountFor,
                    onShareChanged: (value) {
                      setState(() {
                        _share = value;
                        _amountController.text = _formatAmount(_amountFor(value))
                            .replaceAll(RegExp(r'[^0-9.,]'), '');
                      });
                    },
                    onAmountChanged: _syncShareFromAmount,
                  ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                if (_step != _DualPaymentStep.first) ...[
                  TextButton(
                    onPressed: _goBack,
                    child: const Text('Volver'),
                  ),
                ],
                const Spacer(),
                FilledButton(
                  onPressed: _canProceed ? _goNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceTouch,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: Text(
                    _step == _DualPaymentStep.split ? 'Confirmar' : 'Siguiente',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.exclude,
    required this.selected,
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
    required this.onSelected,
    this.mobileHandoff = false,
  });

  final Set<PaymentMethod> exclude;
  final PaymentMethod? selected;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final ValueChanged<PaymentMethod> onSelected;
  final bool mobileHandoff;

  @override
  Widget build(BuildContext context) {
    final methods = _checkoutMethodsFor(
      context,
      cart: cart,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
      totalsService: totalsService,
    ).where((method) => !exclude.contains(method)).toList();
    final listaTotal = totalsService.cartTotalAtMethod(
      cart: cart,
      method: PaymentMethod.lista,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );

    if (mobileHandoff) {
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
                selected: selected == methods[i],
                onTap: () => onSelected(methods[i]),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
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
            listaTotal: listaTotal,
            selected: selected == method,
            onTap: () => onSelected(method),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep({
    required this.first,
    required this.second,
    required this.share,
    required this.total,
    required this.amountController,
    required this.formatAmount,
    required this.amountFor,
    required this.onShareChanged,
    required this.onAmountChanged,
  });

  final PaymentMethod first;
  final PaymentMethod second;
  final double share;
  final double total;
  final TextEditingController amountController;
  final String Function(double amount) formatAmount;
  final double Function(double share) amountFor;
  final ValueChanged<double> onShareChanged;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final firstAmount = amountFor(share);
    final secondAmount = amountFor(1 - share);
    final amountLabel = first.isUsdPayment
        ? 'Monto en USD (${first.shortLabel})'
        : 'Monto en pesos (${first.shortLabel})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(amountLabel, style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(
            hintText: first.isUsdPayment ? 'Ej: 500' : 'Ej: 500000',
            suffixText: first.isUsdPayment ? 'USD' : 'ARS',
          ),
          onChanged: onAmountChanged,
        ),
        const SizedBox(height: 12),
        Text(
          '${(100 * share).round()}% · ${first.shortLabel}',
          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        Slider(
          value: share,
          min: dualPaymentMinShare,
          max: dualPaymentMaxShare,
          divisions: 18,
          label: '${(100 * share).round()}%',
          onChanged: onShareChanged,
        ),
        _SharePreviewRow(
          label: '1. ${first.shortLabel}',
          value: formatAmount(firstAmount),
          total: formatAmount(total),
        ),
        const SizedBox(height: 8),
        _SharePreviewRow(
          label: '2. ${second.shortLabel}',
          value: formatAmount(secondAmount),
          total: formatAmount(total),
        ),
      ],
    );
  }
}

class _SharePreviewRow extends StatelessWidget {
  const _SharePreviewRow({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final String value;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTouch,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'de $total',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
