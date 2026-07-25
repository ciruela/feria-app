import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/sale_record.dart';
import '../../models/sales_metrics.dart';
import '../../services/audit_service.dart';
import '../../services/comprobante_pdf_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

class AdminMetricsScreen extends StatefulWidget {
  const AdminMetricsScreen({super.key});

  @override
  State<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends State<AdminMetricsScreen> {
  final _service = SalesMetricsService();
  DateTime _selectedDay = DateTime.now();
  DaySalesMetrics? _metrics;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useSupabase) {
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final metrics = await _service.metricsForDay(_selectedDay);
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _voidSale(SaleRecord sale) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _VoidReasonDialog(),
    );
    if (motivo == null) return;

    setState(() => _loading = true);
    try {
      final actor = AuditService.instance.actorNombre;
      final ok = await _service.voidSale(
        sale,
        motivo: motivo,
        actorNombre: actor.isEmpty ? 'Admin' : actor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Venta anulada y stock restituido'
                : 'La venta ya estaba anulada',
          ),
        ),
      );
      await _loadMetrics();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular la venta: $error')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;
    setState(() => _selectedDay = picked);
    await _loadMetrics();
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Métricas del día'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadMetrics,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !AppConfig.useSupabase
          ? const _SupabaseRequired()
          : _loading && _metrics == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMetrics,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      _DateSelector(
                        date: _selectedDay,
                        onTap: _pickDate,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: _error!),
                      ],
                      if (_metrics != null) ...[
                        const SizedBox(height: 20),
                        _SummarySection(metrics: _metrics!),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Por categoría',
                          subtitle: 'Unidades vendidas e importes cobrados',
                        ),
                        const SizedBox(height: 12),
                        _CategoryCard(
                          label: 'Armas cortas',
                          metrics: _metrics!.armaCorta,
                          color: AppColors.armaCorta,
                          icon: Icons.shield_rounded,
                        ),
                        const SizedBox(height: 10),
                        _CategoryCard(
                          label: 'Armas largas',
                          metrics: _metrics!.armaLarga,
                          color: AppColors.armaLarga,
                          icon: Icons.sports_martial_arts_rounded,
                        ),
                        const SizedBox(height: 10),
                        _CategoryCard(
                          label: 'Munición',
                          metrics: _metrics!.municion,
                          color: AppColors.municion,
                          icon: Icons.local_fire_department_rounded,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Formas de pago',
                          subtitle: 'Por línea de venta',
                        ),
                        const SizedBox(height: 12),
                        _PaymentSection(payments: _metrics!.payments),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Comprobantes emitidos',
                          subtitle: 'PDF guardados del día',
                        ),
                        const SizedBox(height: 12),
                        _ComprobantesSection(
                          sales: _metrics!.sales,
                          onVoid: _voidSale,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Por vendedor',
                          subtitle: 'Comprobantes del día',
                        ),
                        const SizedBox(height: 12),
                        _SellerSection(sellers: _metrics!.sellers),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SupabaseRequired extends StatelessWidget {
  const _SupabaseRequired();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text(
              'Las métricas requieren Supabase',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Configurá .env y generá comprobantes para acumular ventas en la nube.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());

    return Material(
      color: AppColors.surface,
      borderRadius: AppDecorations.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDecorations.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, color: AppColors.goldDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? 'Hoy' : formatDate(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isToday ? formatDate(date) : 'Tocá para cambiar el día',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.metrics});

  final DaySalesMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatCard(
          icon: Icons.receipt_long_rounded,
          label: 'Comprobantes',
          value: '${metrics.saleCount}',
          subtitle: '${metrics.totalUnits} ítems vendidos',
          accentColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.payments_rounded,
                label: 'Total cobrado ARS',
                value: formatArs(metrics.totalArs),
                accentColor: AppColors.goldDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.attach_money_rounded,
                label: 'Total cobrado USD',
                value: formatUsd(metrics.totalUsd),
                accentColor: AppColors.armaCorta,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.metrics,
    required this.color,
    required this.icon,
  });

  final String label;
  final CategoryMetrics metrics;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  '${metrics.units} unidades',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (metrics.ars > 0)
                Text(formatArs(metrics.ars), style: const TextStyle(fontWeight: FontWeight.w800)),
              if (metrics.usd > 0)
                Text(formatUsd(metrics.usd), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (metrics.units == 0)
                const Text('Sin ventas', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.payments});

  final List<PaymentMetrics> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const _EmptyMetric(message: 'Sin ventas registradas');
    }

    return Column(
      children: payments.map((payment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MetricRow(
            title: payment.label,
            subtitle: '${payment.transactions} operaciones',
            primary: payment.ars > 0 ? formatArs(payment.ars) : formatUsd(payment.usd),
            secondary: payment.ars > 0 && payment.usd > 0 ? formatUsd(payment.usd) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _ComprobantesSection extends StatelessWidget {
  const _ComprobantesSection({required this.sales, required this.onVoid});

  final List<SaleRecord> sales;
  final Future<void> Function(SaleRecord sale) onVoid;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const _EmptyMetric(message: 'Sin comprobantes este día');
    }

    final sorted = [...sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: sorted.map((sale) {
        final time = TimeOfDay.fromDateTime(sale.createdAt);
        final timeLabel =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final client = sale.clienteNombre.trim().isEmpty
            ? 'Sin nombre'
            : sale.clienteNombre.trim();
        final totalParts = <String>[];
        if (sale.collectedArs > 0) {
          totalParts.add(formatArs(sale.collectedArs));
        }
        if (sale.collectedUsd > 0) {
          totalParts.add(formatUsd(sale.collectedUsd));
        }
        final totalLabel =
            totalParts.isEmpty ? 'Sin importe' : totalParts.join(' · ');
        final anulada = sale.anulada;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: anulada
                  ? AppColors.danger.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: AppDecorations.radiusMd,
              border: Border.all(
                color: anulada
                    ? AppColors.danger.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              client,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                decoration: anulada
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: anulada
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (anulada) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ANULADA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '$timeLabel · $totalLabel',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (anulada && sale.anuladaMotivo.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Motivo: ${sale.anuladaMotivo.trim()}'
                            '${sale.anuladaPor.trim().isEmpty ? '' : ' · ${sale.anuladaPor.trim()}'}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (sale.hasPdf) ...[
                  IconButton(
                    tooltip: 'Ver PDF',
                    onPressed: () => _viewPdf(context, sale.pdfPath!),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                  IconButton(
                    tooltip: 'Compartir PDF',
                    onPressed: () => _sharePdf(context, sale.pdfPath!),
                    icon: const Icon(Icons.ios_share_rounded),
                  ),
                ],
                if (!anulada)
                  IconButton(
                    tooltip: 'Anular venta',
                    onPressed: () => onVoid(sale),
                    icon: const Icon(
                      Icons.block_rounded,
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _viewPdf(BuildContext context, String pdfPath) async {
    try {
      await ComprobantePdfService.viewStoredPdf(pdfPath);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $error')),
      );
    }
  }

  Future<void> _sharePdf(BuildContext context, String pdfPath) async {
    try {
      await ComprobantePdfService.shareStoredPdf(pdfPath);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el PDF: $error')),
      );
    }
  }
}

class _VoidReasonDialog extends StatefulWidget {
  const _VoidReasonDialog();

  @override
  State<_VoidReasonDialog> createState() => _VoidReasonDialogState();
}

class _VoidReasonDialogState extends State<_VoidReasonDialog> {
  final _controller = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final next = _controller.text.trim().isNotEmpty;
      if (next != _valid) setState(() => _valid = next);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anular venta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se restituirá el stock y quedará registrado en la auditoría. '
            'Esta acción no se puede deshacer.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Ej: carga errónea, cliente se arrepintió…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Anular venta'),
        ),
      ],
    );
  }
}

class _SellerSection extends StatelessWidget {
  const _SellerSection({required this.sellers});

  final List<SellerMetrics> sellers;

  @override
  Widget build(BuildContext context) {
    if (sellers.isEmpty) {
      return const _EmptyMetric(message: 'Sin vendedores registrados');
    }

    return Column(
      children: sellers.map((seller) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MetricRow(
            title: seller.name,
            subtitle: '${seller.sales} comprobantes',
            primary: formatArs(seller.ars),
            secondary: seller.usd > 0 ? formatUsd(seller.usd) : null,
          ),
        );
      }).toList(),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.title,
    required this.subtitle,
    required this.primary,
    this.secondary,
  });

  final String title;
  final String subtitle;
  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(primary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (secondary != null)
                Text(secondary!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyMetric extends StatelessWidget {
  const _EmptyMetric({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppDecorations.radiusMd,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.danger)),
    );
  }
}
