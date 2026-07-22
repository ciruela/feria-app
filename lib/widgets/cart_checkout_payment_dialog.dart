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
  return showDialog<CartCheckoutPayment>(
    context: context,
    builder: (context) => _CartCheckoutPaymentDialog(current: current),
  );
}

class _CartCheckoutPaymentDialog extends StatelessWidget {
  const _CartCheckoutPaymentDialog({this.current});

  final CartCheckoutPayment? current;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();

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
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.goldDark,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '¿Cómo abona el cliente?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elegí el precio de referencia para todo el carrito '
                    'y, si hace falta, dividí el cobro en dos formas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                children: [
                  FilterChipButton(
                    label: 'PAGAR EN DOS FORMAS',
                    selected: current?.isDual ?? false,
                    onTap: () async {
                      final dual = await _pickDualPayment(
                        context,
                        cart: cart,
                        exchangeRate: exchangeRate,
                        pricingSettings: pricingSettings,
                        totalsService: totalsService,
                      );
                      if (dual != null && context.mounted) {
                        Navigator.of(context).pop(dual);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Una sola forma de pago',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...selectablePaymentMethods.map((method) {
                    final total = totalsService.cartTotalAtMethod(
                      cart: cart,
                      method: method,
                      exchangeRate: exchangeRate,
                      pricingSettings: pricingSettings,
                    );
                    final amount = method.isUsdPayment
                        ? formatUsd(total.usd)
                        : formatArs(total.ars);
                    final selected =
                        current != null && !current!.isDual && current!.pricingMethod == method;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FilterChipButton(
                        label: '${method.shortLabel.toUpperCase()} · $amount',
                        selected: selected,
                        compact: true,
                        onTap: () => Navigator.of(context).pop(
                          CartCheckoutPayment.single(method),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCELAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<CartCheckoutPayment?> _pickDualPayment(
    BuildContext context, {
    required CartService cart,
    required ExchangeRateService exchangeRate,
    required PricingSettingsService pricingSettings,
    required CartTotalsService totalsService,
  }) async {
    final first = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _CartDualStepDialog(
        stepTitle: 'Primera forma de pago',
        exclude: const {},
        cart: cart,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
        totalsService: totalsService,
      ),
    );
    if (first == null || !context.mounted) return null;

    final second = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _CartDualStepDialog(
        stepTitle: 'Segunda forma de pago',
        exclude: {first},
        cart: cart,
        exchangeRate: exchangeRate,
        pricingSettings: pricingSettings,
        totalsService: totalsService,
      ),
    );
    if (second == null || !context.mounted) return null;

    final total = totalsService.cartTotalAtMethod(
      cart: cart,
      method: first,
      exchangeRate: exchangeRate,
      pricingSettings: pricingSettings,
    );

    final share = await showDialog<double>(
      context: context,
      builder: (context) => _CartDualShareDialog(
        first: first,
        second: second,
        totalUsd: total.usd,
        totalArs: total.ars,
      ),
    );
    if (share == null) return null;

    return CartCheckoutPayment.dual(
      pricingMethod: first,
      secondMethod: second,
      primaryShare: share,
    );
  }
}

class _CartDualStepDialog extends StatelessWidget {
  const _CartDualStepDialog({
    required this.stepTitle,
    required this.exclude,
    required this.cart,
    required this.exchangeRate,
    required this.pricingSettings,
    required this.totalsService,
  });

  final String stepTitle;
  final Set<PaymentMethod> exclude;
  final CartService cart;
  final ExchangeRateService exchangeRate;
  final PricingSettingsService pricingSettings;
  final CartTotalsService totalsService;

  @override
  Widget build(BuildContext context) {
    final methods =
        selectablePaymentMethods.where((method) => !exclude.contains(method)).toList();

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
              child: Text(
                stepTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                itemCount: methods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final method = methods[index];
                  final total = totalsService.cartTotalAtMethod(
                    cart: cart,
                    method: method,
                    exchangeRate: exchangeRate,
                    pricingSettings: pricingSettings,
                  );
                  final amount = method.isUsdPayment
                      ? formatUsd(total.usd)
                      : formatArs(total.ars);

                  return FilterChipButton(
                    label: '${method.shortLabel.toUpperCase()} · $amount',
                    selected: false,
                    compact: true,
                    onTap: () => Navigator.of(context).pop(method),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CANCELAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartDualShareDialog extends StatefulWidget {
  const _CartDualShareDialog({
    required this.first,
    required this.second,
    required this.totalUsd,
    required this.totalArs,
  });

  final PaymentMethod first;
  final PaymentMethod second;
  final double totalUsd;
  final double totalArs;

  @override
  State<_CartDualShareDialog> createState() => _CartDualShareDialogState();
}

class _CartDualShareDialogState extends State<_CartDualShareDialog> {
  final _amountController = TextEditingController();
  double _share = 0.5;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _total =>
      widget.first.isUsdPayment ? widget.totalUsd : widget.totalArs;

  double _amountFor(double share) => _total * share;

  String _formatAmount(double amount) {
    return widget.first.isUsdPayment ? formatUsd(amount) : formatArs(amount);
  }

  void _syncShareFromAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0 || _total <= 0) return;

    setState(() {
      _share = (amount / _total).clamp(dualPaymentMinShare, dualPaymentMaxShare);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstAmount = _amountFor(_share);
    final secondAmount = _amountFor(1 - _share);
    final amountLabel = widget.first.isUsdPayment
        ? 'Monto en USD (${widget.first.shortLabel})'
        : 'Monto en pesos (${widget.first.shortLabel})';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Dividir el pago',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Indicá cuánto paga con ${widget.first.shortLabel} '
                'y el resto queda en ${widget.second.shortLabel}.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                amountLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  hintText: widget.first.isUsdPayment ? 'Ej: 500' : 'Ej: 500000',
                  suffixText: widget.first.isUsdPayment ? 'USD' : 'ARS',
                ),
                onChanged: _syncShareFromAmount,
              ),
              const SizedBox(height: 12),
              Text(
                '${(100 * _share).round()}% · ${widget.first.shortLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Slider(
                value: _share,
                min: dualPaymentMinShare,
                max: dualPaymentMaxShare,
                divisions: 18,
                label: '${(100 * _share).round()}%',
                onChanged: (value) {
                  setState(() {
                    _share = value;
                    _amountController.text = _formatAmount(_amountFor(value))
                        .replaceAll(RegExp(r'[^0-9.,]'), '');
                  });
                },
              ),
              _SharePreviewRow(
                label: '1. ${widget.first.shortLabel}',
                value: _formatAmount(firstAmount),
                total: _formatAmount(_total),
              ),
              const SizedBox(height: 8),
              _SharePreviewRow(
                label: '2. ${widget.second.shortLabel}',
                value: _formatAmount(secondAmount),
                total: _formatAmount(_total),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('CANCELAR'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_share),
                    child: const Text('CONFIRMAR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
