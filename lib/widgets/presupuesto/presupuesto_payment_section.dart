import 'package:flutter/material.dart';

import '../../models/presupuesto_branding.dart';
import '../../models/presupuesto_document.dart';
import '../../models/presupuesto_summary.dart';

class PresupuestoTotalsSection extends StatelessWidget {
  const PresupuestoTotalsSection({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final PresupuestoSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Total:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          Text(
            summary.formattedCombinedTotal,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      );
    }

    final totals = <Widget>[];

    if (summary.hasUsdTotal) {
      totals.add(
        _TotalBox(
          label: 'TOTAL U\$S',
          value: summary.formattedUsdTotal,
        ),
      );
    }
    if (summary.hasArsTotal) {
      totals.add(
        _TotalBox(
          label: 'TOTAL \$',
          value: summary.formattedArsTotal,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < totals.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              totals[i],
            ],
          ],
        ),
      ],
    );
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PresupuestoPaymentSection extends StatelessWidget {
  const PresupuestoPaymentSection({
    super.key,
    required this.branding,
    required this.summary,
  });

  final PresupuestoBranding branding;
  final PresupuestoSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!branding.showsPaymentChecks) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.paymentAllocationLines.isNotEmpty) ...[
          _PaymentAllocationSection(
            branding: branding,
            lines: summary.paymentAllocationLines,
          ),
          const SizedBox(height: 8),
        ],
        _PaymentChecks(branding: branding, summary: summary),
      ],
    );
  }
}

class _PaymentAllocationSection extends StatelessWidget {
  const _PaymentAllocationSection({
    required this.branding,
    required this.lines,
  });

  final PresupuestoBranding branding;
  final List<PaymentAllocationLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branding.paymentAllocationTitle,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· ${line.displayText}',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentChecks extends StatelessWidget {
  const _PaymentChecks({
    required this.branding,
    required this.summary,
  });

  final PresupuestoBranding branding;
  final PresupuestoSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final check in summary.primaryPaymentChecks)
              _Check(label: check.label, checked: check.checked),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              branding.creditCardsTitle,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final check in summary.creditCardChecks)
                    _Check(label: check.label, checked: check.checked),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: checked
              ? const Text(
                  'X',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                )
              : null,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
