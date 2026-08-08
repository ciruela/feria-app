import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/sales_metrics.dart';
import '../../services/catalog_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import 'admin_comprobantes_screen.dart';

class AdminMetricsScreen extends StatefulWidget {
  const AdminMetricsScreen({super.key});

  @override
  State<AdminMetricsScreen> createState() => _AdminMetricsScreenState();
}

class _AdminMetricsScreenState extends State<AdminMetricsScreen> {
  SalesMetricsService? _service;
  DateTime _selectedDay = DateTime.now();
  DaySalesMetrics? _metrics;
  bool _loading = false;
  String? _error;

  bool _metricsRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= SalesMetricsService(
      catalog: context.read<CatalogService>(),
    );
    if (AppConfig.useSupabase && !_metricsRequested) {
      _metricsRequested = true;
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = _service;
      if (service == null) return;
      final metrics = await service.metricsForDay(_selectedDay);
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
                        _SummarySection(
                          metrics: _metrics!,
                          onComprobantesTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AdminComprobantesScreen(
                                  initialDate: _selectedDay,
                                ),
                              ),
                            );
                          },
                        ),
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
                          balas: _metrics!.municionBalas,
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
  const _SummarySection({
    required this.metrics,
    required this.onComprobantesTap,
  });

  final DaySalesMetrics metrics;
  final VoidCallback onComprobantesTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatCard(
          icon: Icons.receipt_long_rounded,
          label: 'Comprobantes',
          value: '${metrics.saleCount}',
          subtitle: 'Tocá para ver, descargar o compartir PDFs',
          accentColor: AppColors.primary,
          onTap: onComprobantesTap,
        ),
        const SizedBox(height: 12),
        // AR-53: sin icono — en mobile el monto quedaba achicado.
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total cobrado ARS',
                value: formatArs(metrics.totalArs),
                accentColor: AppColors.goldDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
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
    this.balas,
  });

  final String label;
  final CategoryMetrics metrics;
  final Color color;
  final IconData icon;

  /// Balas vendidas de munición. Solo cuando es > 0 (hay `roundsPerBox`) se
  /// muestra "cajas · balas"; si no, se usa "unidades" para no alterar la
  /// vista de tenants que no manejan munición con balas por caja (p. ej. Urban).
  final int? balas;

  String get _unitsLabel {
    if (balas != null && balas! > 0) {
      return '${metrics.units} cajas · $balas balas';
    }
    return '${metrics.units} unidades';
  }

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
                  _unitsLabel,
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
