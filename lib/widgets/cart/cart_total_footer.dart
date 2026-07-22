import 'package:flutter/material.dart';

import '../../models/cart_checkout_payment.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

class CartTotalFooter extends StatelessWidget {
  const CartTotalFooter({
    super.key,
    required this.totalUsd,
    required this.totalArs,
    required this.hasUsdPayments,
    required this.hasArsPayments,
    required this.paymentAllocations,
    required this.checkoutConfigured,
    this.onOpenBudget,
  });

  final double totalUsd;
  final double totalArs;
  final bool hasUsdPayments;
  final bool hasArsPayments;
  final List<PaymentAllocation> paymentAllocations;
  final bool checkoutConfigured;
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final showBoth = hasUsdPayments && hasArsPayments;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: AppDecorations.cardGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!checkoutConfigured)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Configurá cómo abona el cliente para continuar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          if (paymentAllocations.length > 1) ...[
            ...paymentAllocations.map(
              (allocation) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        allocation.method.shortLabel.toUpperCase(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      allocation.paysInUsd
                          ? formatUsd(allocation.amountUsd)
                          : formatArs(allocation.amountArs),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (showBoth)
            Row(
              children: [
                Expanded(
                  child: _FooterTotalColumn(
                    label: 'TOTAL USD',
                    value: formatUsd(totalUsd),
                    valueColor: Colors.white,
                  ),
                ),
                Container(
                  width: 1,
                  height: 56,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _FooterTotalColumn(
                    label: 'TOTAL ARS',
                    value: formatArs(totalArs),
                    valueColor: AppColors.gold,
                  ),
                ),
              ],
            )
          else
            _FooterTotalColumn(
              label: hasUsdPayments ? 'TOTAL USD' : 'TOTAL ARS',
              value: hasUsdPayments ? formatUsd(totalUsd) : formatArs(totalArs),
              valueColor: hasUsdPayments ? Colors.white : AppColors.gold,
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppDecorations.goldGradient,
                borderRadius: AppDecorations.radiusMd,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onOpenBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('GENERAR COMPROBANTE'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterTotalColumn extends StatelessWidget {
  const _FooterTotalColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: valueColor,
              ),
        ),
      ],
    );
  }
}
