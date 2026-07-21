import 'package:flutter/material.dart';

import '../models/product_prices.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ProductPricesPanel extends StatelessWidget {
  const ProductPricesPanel({
    super.key,
    required this.prices,
    this.compact = false,
  });

  final ProductPrices prices;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceLine(
          label: 'USD',
          value: formatUsd(prices.usd),
          bold: true,
        ),
        _PriceLine(
          label: 'LISTA',
          value: formatArs(prices.lista),
          bold: !compact,
          large: !compact,
        ),
        _PriceLine(
          label: 'EFECTIVO',
          value: formatArs(prices.efectivo),
          color: AppColors.accent,
        ),
        _PriceLine(
          label: 'TARJETA 3x',
          value:
              '${formatArs(prices.tarjeta3)} (${formatArs(prices.cuota3)}/cuota)',
        ),
        _PriceLine(
          label: 'TARJETA 6x',
          value:
              '${formatArs(prices.tarjeta6)} (${formatArs(prices.cuota6)}/cuota)',
        ),
        _PriceLine(
          label: 'TARJETA 12x',
          value:
              '${formatArs(prices.tarjeta12)} (${formatArs(prices.cuota12)}/cuota)',
        ),
      ],
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.bold = false,
    this.large = false,
    this.color,
  });

  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: large ? 20 : 16,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
