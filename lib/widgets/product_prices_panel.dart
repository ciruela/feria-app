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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppDecorations.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PriceLine(
            label: 'USD',
            value: formatUsd(prices.usd),
            bold: true,
            highlight: true,
            compact: compact,
          ),
          const Divider(height: 18),
          _PriceLine(
            label: 'LISTA',
            value: formatArs(prices.lista),
            bold: !compact,
            large: !compact,
            compact: compact,
          ),
          _PriceLine(
            label: 'EFECTIVO',
            value: formatArs(prices.efectivo),
            compact: compact,
          ),
          _PriceLine(
            label: 'TRANSFER.',
            value: formatArs(prices.lista),
            compact: compact,
          ),
          _PriceLine(
            label: 'DÉBITO',
            value: formatArs(prices.debito),
            compact: compact,
          ),
          _PriceLine(
            label: '1 CUOTA',
            value: formatArs(prices.tarjeta1),
            compact: compact,
          ),
          _PriceLine(
            label: '3 CUOTAS',
            value:
                '${formatArs(prices.tarjeta3)} (${formatArs(prices.cuota3)}/cuota)',
            compact: compact,
            multiline: compact,
          ),
          _PriceLine(
            label: '6 CUOTAS',
            value:
                '${formatArs(prices.tarjeta6)} (${formatArs(prices.cuota6)}/cuota)',
            compact: compact,
            multiline: compact,
          ),
          _PriceLine(
            label: '9 CUOTAS',
            value:
                '${formatArs(prices.tarjeta9)} (${formatArs(prices.cuota9)}/cuota)',
            compact: compact,
            multiline: compact,
          ),
          _PriceLine(
            label: '12 CUOTAS',
            value:
                '${formatArs(prices.tarjeta12)} (${formatArs(prices.cuota12)}/cuota)',
            compact: compact,
            multiline: compact,
          ),
          _PriceLine(
            label: '18 CUOTAS',
            value:
                '${formatArs(prices.tarjeta18)} (${formatArs(prices.cuota18)}/cuota)',
            compact: compact,
            multiline: compact,
          ),
        ],
      ),
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
    this.highlight = false,
    this.compact = false,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? color;
  final bool highlight;
  final bool compact;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final labelWidth = compact ? 88.0 : 96.0;
    final valueSize = large ? 22.0 : (compact ? 14.0 : 16.0);
    final labelSize = large ? 18.0 : (compact ? 12.0 : 14.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.goldDark : AppColors.textSecondary,
                letterSpacing: 0.4,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: multiline ? 2 : 1,
              softWrap: multiline,
              overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
