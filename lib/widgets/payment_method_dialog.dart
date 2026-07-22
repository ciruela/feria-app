import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_prices.dart';
import '../models/weapon_payment_selection.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_service.dart';
import '../services/pricing_settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'filter_buttons.dart';

Future<WeaponPaymentSelection?> showWeaponPaymentDialog(
  BuildContext context, {
  required Product product,
}) {
  return showDialog<WeaponPaymentSelection>(
    context: context,
    builder: (context) => _WeaponPaymentDialog(product: product),
  );
}

Future<PaymentMethod?> showSinglePaymentDialog(
  BuildContext context, {
  required Product product,
  PaymentMethod? current,
}) {
  return showDialog<PaymentMethod>(
    context: context,
    builder: (context) => _SinglePaymentDialog(
      product: product,
      current: current,
    ),
  );
}

@Deprecated('Usar showWeaponPaymentDialog')
Future<PaymentMethod?> showPaymentMethodDialog(
  BuildContext context, {
  required Product product,
}) async {
  final selection = await showWeaponPaymentDialog(context, product: product);
  return selection?.first;
}

class _WeaponPaymentDialog extends StatelessWidget {
  const _WeaponPaymentDialog({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final title = product.isArma ? product.modeloDisplay : product.codigo;

    return _PaymentShell(
      title: '¿Cómo abona el comprador?',
      subtitle: '${product.marcaUpper} · $title',
      child: Column(
        children: [
          FilterChipButton(
            label: 'PAGAR EN DOS FORMAS',
            selected: false,
            onTap: () async {
              final dual = await _pickDualPayment(context);
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
          _PaymentMethodList(
            exclude: const {},
            product: product,
            onSelected: (method) => Navigator.of(context).pop(
              WeaponPaymentSelection.single(method),
            ),
          ),
        ],
      ),
    );
  }

  Future<WeaponPaymentSelection?> _pickDualPayment(BuildContext context) async {
    final first = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _DualStepDialog(
        stepTitle: 'Primera forma de pago',
        product: product,
      ),
    );
    if (first == null || !context.mounted) return null;

    final second = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => _DualStepDialog(
        stepTitle: 'Segunda forma de pago',
        product: product,
        exclude: {first},
      ),
    );
    if (second == null || !context.mounted) return null;

    final share = await showDialog<double>(
      context: context,
      builder: (context) => _DualShareDialog(
        product: product,
        first: first,
        second: second,
      ),
    );
    if (share == null) return null;

    return WeaponPaymentSelection.dual(
      first: first,
      second: second,
      firstShare: share,
    );
  }
}

class _SinglePaymentDialog extends StatelessWidget {
  const _SinglePaymentDialog({
    required this.product,
    this.current,
  });

  final Product product;
  final PaymentMethod? current;

  @override
  Widget build(BuildContext context) {
    final title = product.isArma ? product.modeloDisplay : product.codigo;

    return _PaymentShell(
      title: 'Forma de pago',
      subtitle: '${product.marcaUpper} · $title',
      child: _AllPaymentMethodList(
        product: product,
        current: current,
        onSelected: (method) => Navigator.of(context).pop(method),
      ),
    );
  }
}

class _AllPaymentMethodList extends StatelessWidget {
  const _AllPaymentMethodList({
    required this.product,
    required this.onSelected,
    this.current,
  });

  final Product product;
  final PaymentMethod? current;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final settings = context.watch<PricingSettingsService>();
    final prices = PricingService().pricesFor(product, exchangeRate, settings);

    return ListView.separated(
      shrinkWrap: true,
      itemCount: selectablePaymentMethods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final method = selectablePaymentMethods[index];
        final amount = method.isUsdPayment
            ? formatUsd(prices.usd)
            : formatArs(method.totalArsFor(prices));
        final selected = current == method;

        return FilterChipButton(
          label: '${method.shortLabel.toUpperCase()} · $amount',
          selected: selected,
          compact: true,
          onTap: () => onSelected(method),
        );
      },
    );
  }
}

class _DualStepDialog extends StatelessWidget {
  const _DualStepDialog({
    required this.stepTitle,
    required this.product,
    this.exclude = const {},
  });

  final String stepTitle;
  final Product product;
  final Set<PaymentMethod> exclude;

  @override
  Widget build(BuildContext context) {
    final title = product.isArma ? product.modeloDisplay : product.codigo;

    return _PaymentShell(
      title: stepTitle,
      subtitle: '${product.marcaUpper} · $title',
      child: _PaymentMethodList(
        exclude: exclude,
        product: product,
        onSelected: (method) => Navigator.of(context).pop(method),
      ),
    );
  }
}

class _DualShareDialog extends StatefulWidget {
  const _DualShareDialog({
    required this.product,
    required this.first,
    required this.second,
  });

  final Product product;
  final PaymentMethod first;
  final PaymentMethod second;

  @override
  State<_DualShareDialog> createState() => _DualShareDialogState();
}

class _DualShareDialogState extends State<_DualShareDialog> {
  final _amountController = TextEditingController();
  double _share = 0.5;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  ProductPrices get _prices {
    final exchangeRate = context.read<ExchangeRateService>();
    final settings = context.read<PricingSettingsService>();
    return PricingService().pricesFor(
      widget.product,
      exchangeRate,
      settings,
    );
  }

  double _amountFor(PaymentMethod method, double share) {
    if (method.isUsdPayment) return _prices.usd * share;
    return method.totalArsFor(_prices) * share;
  }

  String _formatAmount(PaymentMethod method, double amount) {
    return method.isUsdPayment ? formatUsd(amount) : formatArs(amount);
  }

  void _syncShareFromAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) return;

    final total = widget.first.isUsdPayment
        ? _prices.usd
        : widget.first.totalArsFor(_prices);
    if (total <= 0) return;

    setState(() {
      _share = (amount / total).clamp(0.05, 0.95);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstAmount = _amountFor(widget.first, _share);
    final secondAmount = _amountFor(widget.second, 1 - _share);
    final firstTotal = _amountFor(widget.first, 1);
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
                min: 0.05,
                max: 0.95,
                divisions: 18,
                label: '${(100 * _share).round()}%',
                onChanged: (value) {
                  setState(() {
                    _share = value;
                    _amountController.text = _formatAmount(
                      widget.first,
                      _amountFor(widget.first, value),
                    ).replaceAll(RegExp(r'[^0-9.,]'), '');
                  });
                },
              ),
              _SharePreviewRow(
                label: '1. ${widget.first.shortLabel}',
                value: _formatAmount(widget.first, firstAmount),
                total: _formatAmount(widget.first, firstTotal),
              ),
              const SizedBox(height: 8),
              _SharePreviewRow(
                label: '2. ${widget.second.shortLabel}',
                value: _formatAmount(widget.second, secondAmount),
                total: _formatAmount(widget.second, _amountFor(widget.second, 1)),
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

class _PaymentMethodList extends StatelessWidget {
  const _PaymentMethodList({
    required this.exclude,
    required this.onSelected,
    required this.product,
  });

  final Set<PaymentMethod> exclude;
  final ValueChanged<PaymentMethod> onSelected;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();
    final settings = context.watch<PricingSettingsService>();
    final prices = PricingService().pricesFor(product, exchangeRate, settings);
    final methods =
        weaponPaymentMethods.where((method) => !exclude.contains(method)).toList();

    return ListView.separated(
      shrinkWrap: true,
      itemCount: methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final method = methods[index];
        final amount = method.isUsdPayment
            ? formatUsd(prices.usd)
            : formatArs(method.totalArsFor(prices));

        return FilterChipButton(
          label: '${method.shortLabel.toUpperCase()} · $amount',
          selected: false,
          compact: true,
          onTap: () => onSelected(method),
        );
      },
    );
  }
}

class _PaymentShell extends StatelessWidget {
  const _PaymentShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
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
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: child),
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
