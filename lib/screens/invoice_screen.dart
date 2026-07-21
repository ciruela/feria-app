import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/invoice.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/feria_shell.dart';

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({
    super.key,
    required this.invoice,
  });

  final Invoice invoice;

  String _plainText() {
    final buffer = StringBuffer()
      ..writeln('COMPROBANTE DE VENTA')
      ..writeln('Fecha: ${formatDate(invoice.date)}')
      ..writeln('Cliente: ${invoice.buyerFullName}');

    if (invoice.sellerName != null) {
      buffer.writeln('Vendedor: ${invoice.sellerName}');
    }

    buffer.writeln('');
    buffer.writeln('PRODUCTOS');
    buffer.writeln('────────────────────────────');

    for (final line in invoice.lines) {
      buffer.writeln(line.productName);
      buffer.writeln('Cód. interno: ${line.internalCode}');
      if (line.productCode.isNotEmpty &&
          line.productCode != line.internalCode) {
        buffer.writeln('Código: ${line.productCode}');
      }
      buffer.writeln(
        'Cant: ${line.quantity} · ${line.paymentLabel} · '
        '${formatUsd(line.lineUsd)} · ${formatArs(line.lineArs)}',
      );
      buffer.writeln('');
    }

    buffer
      ..writeln('────────────────────────────')
      ..writeln('TOTAL USD: ${formatUsd(invoice.totalUsd)}')
      ..writeln('TOTAL ARS: ${formatArs(invoice.totalArs)}');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Comprobante'),
        actions: [
          IconButton(
            tooltip: 'Copiar',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _plainText()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comprobante copiado')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InvoicePaper(invoice: invoice),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _plainText()));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comprobante copiado')),
              );
            },
            icon: const Icon(Icons.copy_all_rounded),
            label: const Text('COPIAR COMPROBANTE'),
          ),
        ],
      ),
    );
  }
}

class _InvoicePaper extends StatelessWidget {
  const _InvoicePaper({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: [AppDecorations.cardShadow],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppDecorations.goldGradient,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'COMPROBANTE DE VENTA',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formatDate(invoice.date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoBlock(
            label: 'CLIENTE',
            value: invoice.buyerFullName,
          ),
          if (invoice.sellerName != null) ...[
            const SizedBox(height: 12),
            _InfoBlock(
              label: 'VENDEDOR',
              value: invoice.sellerName!,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 2),
          ),
          Text(
            'PRODUCTOS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          ...invoice.lines.map((line) => _InvoiceLineCard(line: line)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 2),
          ),
          Row(
            children: [
              Expanded(
                child: _TotalBlock(
                  label: 'TOTAL USD',
                  value: formatUsd(invoice.totalUsd),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TotalBlock(
                  label: 'TOTAL ARS',
                  value: formatArs(invoice.totalArs),
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _InvoiceLineCard extends StatelessWidget {
  const _InvoiceLineCard({required this.line});

  final InvoiceLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.productName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Cód. interno', value: line.internalCode),
          if (line.productCode.isNotEmpty &&
              line.productCode != line.internalCode)
            _DetailRow(label: 'Código', value: line.productCode),
          _DetailRow(label: 'Cantidad', value: '${line.quantity}'),
          _DetailRow(label: 'Forma de pago', value: line.paymentLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatUsd(line.lineUsd),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                formatArs(line.lineArs),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
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

class _TotalBlock extends StatelessWidget {
  const _TotalBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
