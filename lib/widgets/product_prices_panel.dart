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
          ),
          const Divider(height: 18),
          _PriceLine(
            label: 'LISTA',
            value: formatArs(prices.lista),
            bold: !compact,
            large: !compact,
          ),
          _PriceLine(
            label: 'EFECTIVO',
            value: formatArs(prices.efectivo),
          ),
          _PriceLine(
            label: 'TRANSFER.',
            value: formatArs(prices.lista),
          ),
          _PriceLine(
            label: 'DÉBITO',
            value: formatArs(prices.debito),
          ),
          _PriceLine(
            label: '1 CUOTA',
            value: formatArs(prices.tarjeta1),
          ),
          _PriceLine(
            label: '3 CUOTAS',
            value:
                '${formatArs(prices.tarjeta3)} (${formatArs(prices.cuota3)}/cuota)',
          ),
          _PriceLine(
            label: '6 CUOTAS',
            value:
                '${formatArs(prices.tarjeta6)} (${formatArs(prices.cuota6)}/cuota)',
          ),
          _PriceLine(
            label: '9 CUOTAS',
            value:
                '${formatArs(prices.tarjeta9)} (${formatArs(prices.cuota9)}/cuota)',
          ),
          _PriceLine(
            label: '12 CUOTAS',
            value:
                '${formatArs(prices.tarjeta12)} (${formatArs(prices.cuota12)}/cuota)',
          ),
          _PriceLine(
            label: '18 CUOTAS',
            value:
                '${formatArs(prices.tarjeta18)} (${formatArs(prices.cuota18)}/cuota)',
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
  });

  final String label;
  final String value;
  final bool bold;
  final bool large;
  final Color? color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: large ? 18 : 14,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.goldDark : AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: large ? 22 : 16,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
