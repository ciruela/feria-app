import 'package:flutter/material.dart';

import '../../models/product_prices.dart';
import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/uppercase_input.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
    required this.prices,
    required this.lineUsd,
    required this.lineArs,
    required this.displayMethod,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    this.onSerialChanged,
  });

  final CartItem item;
  final ProductPrices prices;
  final double lineUsd;
  final double lineArs;
  final PaymentMethod displayMethod;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String>? onSerialChanged;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final paysInUsd = displayMethod.isUsdPayment;
    final primaryLabel = paysInUsd ? 'TOTAL USD' : 'TOTAL ARS';
    final primaryValue = paysInUsd ? formatUsd(lineUsd) : formatArs(lineArs);
    final referenceValue = paysInUsd
        ? 'Ref. lista: ${formatArs(prices.lista * item.quantity)}'
        : 'Catálogo: ${formatUsd(prices.usd * item.quantity)}';

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
          if (onSerialChanged != null) ...[
            const SizedBox(height: 10),
            CartSerialField(
              initialValue: item.serialNumber,
              onChanged: onSerialChanged!,
            ),
          ],
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
          Row(
            children: [
              CartQtyButton(icon: Icons.remove, onTap: onDecrease),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              CartQtyButton(
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

class CartQtyButton extends StatelessWidget {
  const CartQtyButton({
    super.key,
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

class CartSerialField extends StatefulWidget {
  const CartSerialField({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<CartSerialField> createState() => _CartSerialFieldState();
}

class _CartSerialFieldState extends State<CartSerialField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(CartSerialField oldWidget) {
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
