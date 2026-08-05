import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'filter_buttons.dart';

Future<CartCheckoutPayment?> showCartCheckoutPaymentDialog(
  BuildContext context, {
  CartCheckoutPayment? current,
}) {
  final useSheet = MediaQuery.sizeOf(context).width < 960;

  if (useSheet) {
    return showModalBottomSheet<CartCheckoutPayment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
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
          maxChildSize: 0.92,
          builder: (_, scrollController) => _CartCheckoutPaymentDialog(
            current: current,
            scrollController: scrollController,
            asSheet: true,
          ),
        ),
      ),
    );
  }

  return showDialog<CartCheckoutPayment>(
    context: context,
    builder: (context) => _CartCheckoutPaymentDialog(current: current),
  );
}

class _CartCheckoutPaymentDialog extends StatelessWidget {
  const _CartCheckoutPaymentDialog({
    this.current,
    this.scrollController,
    this.asSheet = false,
  });

  final CartCheckoutPayment? current;
  final ScrollController? scrollController;
  final bool asSheet;

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

    if (asSheet) return content;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radius),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: asSheet ? double.infinity : 480,
        maxHeight: asSheet
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asSheet)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Text(
                  '¿Cómo abona el cliente?',
                  textAlign: TextAlign.center,
                  style: AppText.heading,
                ),
                SizedBox(height: 6),
                Text(
                  'Define el precio de referencia del comprobante. '
                  'Si hace falta, dividí el cobro en dos formas y repartí '
                  'el monto de lista entre ambas.',
                  textAlign: TextAlign.center,
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkWrap: true,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final dual = await showDialog<CartCheckoutPayment>(
                      context: context,
                      builder: (context) => _CartDualPaymentWizardDialog(
                        cart: cart,
                        exchangeRate: exchangeRate,
                        pricingSettings: pricingSettings,
                        totalsService: totalsService,
                      ),
                    );
                    if (dual != null && context.mounted) {
                      Navigator.of(context).pop(dual);
                    }
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Pagar en dos formas'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                const SizedBox(height: 12),
                ...selectablePaymentMethods.map((method) {
                  final total = totalsService.cartTotalAtMethod(
                    cart: cart,
                    method: method,
                    exchangeRate: exchangeRate,
                    pricingSettings: pricingSettings,
                  );
                  final selected = current != null &&
                      !current!.isDual &&
                      current!.pricingMethod == method;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PaymentMethodRow(
                      method: method,
                      total: total,
                      selected: selected,
                      onTap: () => Navigator.of(context).pop(
                        CartCheckoutPayment.single(method),
                      ),
                    ),
                  );
                }),
              ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceTouch,
                    foregroundColor: AppColors.textPrimary,
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
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final CartLineTotal total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount =
        method.isUsdPayment ? formatUsd(total.usd) : formatArs(total.ars);
    final installments = _installmentCount(method);
    String? installmentDetail;
    if (installments != null && installments > 1 && !method.isUsdPayment) {
      final cuota = total.ars / installments;
      installmentDetail = '$installments x ${formatArs(cuota)}';
    }

    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.shortLabel,
                      style: AppText.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.surface : AppColors.textPrimary,
                      ),
                    ),
                    if (installmentDetail != null)
                      Text(
                        installmentDetail,
                        style: AppText.bodySmall.copyWith(
                          color: selected ? AppColors.surface : AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                amount,
                style: AppText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.surface : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DualPaymentStep { first, second, split }

class _CartDualPaymentWizardDialog extends StatefulWidget {
  const _CartDualPaymentWizardDialog({
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
  });

  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;

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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                children: [
                  Text(
                    _stepTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_stepSubtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _stepSubtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: switch (_step) {
                  _DualPaymentStep.first || _DualPaymentStep.second =>
                    _MethodPicker(
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCELAR'),
                  ),
                  if (_step != _DualPaymentStep.first) ...[
                    TextButton(
                      onPressed: _goBack,
                      child: const Text('VOLVER'),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: _canProceed ? _goNext : null,
                    child: Text(
                      _step == _DualPaymentStep.split ? 'CONFIRMAR' : 'SIGUIENTE',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
  });

  final Set<PaymentMethod> exclude;
  final PaymentMethod? selected;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    final methods = selectablePaymentMethods
        .where((method) => !exclude.contains(method))
        .toList();

    return Column(
      children: [
        for (final method in methods) ...[
          FilterChipButton(
            label: _methodLabel(method),
            selected: selected == method,
            compact: true,
            onTap: () => onSelected(method),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _methodLabel(PaymentMethod method) {
    final total = totalsService.cartTotalAtMethod(
      cart: cart,
      method: method,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );
    final amount =
        method.isUsdPayment ? formatUsd(total.usd) : formatArs(total.ars);
    return '${method.shortLabel.toUpperCase()} · $amount';
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
        Text(
          amountLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'de $total',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
