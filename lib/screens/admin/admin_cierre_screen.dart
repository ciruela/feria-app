import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/sale_record.dart';
import '../../models/sales_metrics.dart';
import '../../services/catalog_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../services/stock_cierre_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import 'admin_comprobantes_screen.dart';

class AdminCierreScreen extends StatefulWidget {
  const AdminCierreScreen({super.key});

  @override
  State<AdminCierreScreen> createState() => _AdminCierreScreenState();
}

class _AdminCierreScreenState extends State<AdminCierreScreen> {
  final _cierreService = StockCierreService();
  SalesMetricsService? _salesService;

  DateTime _selectedDay = DateTime.now();
  CierreResumen? _resumen;
  DaySalesMetrics? _ventas;
  StockAlCierre? _stockAlCierre;
  bool _loading = false;
  bool _exporting = false;
  bool _didInitialLoad = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _salesService ??= SalesMetricsService(
      catalog: context.read<CatalogService>(),
    );
    if (!_didInitialLoad && AppConfig.useSupabase) {
      _didInitialLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = context.read<CatalogService>().products;
      final salesService = _salesService;
      if (salesService == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        _cierreService.cierreForDay(_selectedDay, products),
        salesService.metricsForDay(_selectedDay),
      ]);

      if (!mounted) return;
      setState(() {
        _resumen = results[0] as CierreResumen;
        _ventas = results[1] as DaySalesMetrics;
        _stockAlCierre = _cierreService.stockAlCierre(products);
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
    await _load();
  }

  Future<void> _export() async {
    final resumen = _resumen;
    final ventas = _ventas;
    final stock = _stockAlCierre;
    if (resumen == null || ventas == null || stock == null) return;

    setState(() => _exporting = true);
    try {
      final bytes = _cierreService.exportCierreCompleto(
        resumen: resumen,
        ventas: ventas.sales,
        stockAlCierre: stock,
      );
      final stamp = DateFormatCompat.file(_selectedDay);
      await FilePicker.saveFile(
        fileName: 'cierre_completo_$stamp.xlsx',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre completo exportado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openComprobantes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminComprobantesScreen(initialDate: _selectedDay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Cierre de día'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: (_resumen == null || !AppConfig.useSupabase)
          ? null
          : FloatingActionButton.extended(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('EXPORTAR CIERRE'),
            ),
      body: !AppConfig.useSupabase
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'El cierre de día requiere Supabase configurado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ),
            )
          : _loading && _resumen == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                    children: [
                      _DateSelector(date: _selectedDay, onTap: _pickDate),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _Banner(message: _error!),
                      ],
                      if (_resumen != null &&
                          _ventas != null &&
                          _stockAlCierre != null) ...[
                        const SizedBox(height: 20),
                        _ResumenEjecutivo(
                          resumen: _resumen!,
                          ventas: _ventas!,
                          stock: _stockAlCierre!,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Ventas del día',
                          subtitle: 'Comprobantes emitidos y cobros',
                        ),
                        const SizedBox(height: 12),
                        _VentasSection(
                          metrics: _ventas!,
                          onVerTodos: _openComprobantes,
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Stock al cierre',
                          subtitle: 'Totales actuales del inventario',
                        ),
                        const SizedBox(height: 12),
                        _StockAlCierreCard(stock: _stockAlCierre!),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Movimientos de stock',
                          subtitle:
                              'Solo productos con ventas, cargas o ajustes hoy',
                        ),
                        const SizedBox(height: 12),
                        ..._movimientoLines(_resumen!),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<Widget> _movimientoLines(CierreResumen resumen) {
    final activos = resumen.conActividad.toList();
    if (activos.isEmpty) {
      return const [
        _EmptyRow('Sin movimientos de stock en este día'),
      ];
    }

    final muni = activos.where((l) => l.isMunicion).toList();
    final armas = activos.where((l) => !l.isMunicion).toList();

    return [
      if (muni.isNotEmpty) ...[
        const _SubsectionLabel('Munición'),
        const SizedBox(height: 8),
        ...muni.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CierreLineCard(line: line),
          ),
        ),
      ],
      if (armas.isNotEmpty) ...[
        if (muni.isNotEmpty) const SizedBox(height: 8),
        const _SubsectionLabel('Armas'),
        const SizedBox(height: 8),
        ...armas.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CierreLineCard(line: line),
          ),
        ),
      ],
    ];
  }
}

class DateFormatCompat {
  static String file(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}';
  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formatDate(date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenEjecutivo extends StatelessWidget {
  const _ResumenEjecutivo({
    required this.resumen,
    required this.ventas,
    required this.stock,
  });

  final CierreResumen resumen;
  final DaySalesMetrics ventas;
  final StockAlCierre stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESUMEN DEL DÍA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _TotalCell(
                label: 'Comprobantes',
                value: '${ventas.saleCount}',
              ),
              _TotalCell(
                label: 'Cajas vend.',
                value: '${resumen.totalCajasVendidas}',
              ),
              _TotalCell(
                label: 'Armas vend.',
                value: '${resumen.totalArmasVendidas}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cobrado: ${formatArs(ventas.totalArs)} · ${formatUsd(ventas.totalUsd)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stock actual: ${stock.productosConStock} productos · '
            '${stock.cajasMunicion} cajas · ${stock.balasMunicion} balas · '
            '${stock.unidadesArmas} armas',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VentasSection extends StatelessWidget {
  const _VentasSection({
    required this.metrics,
    required this.onVerTodos,
  });

  final DaySalesMetrics metrics;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    if (metrics.saleCount == 0) {
      return const _EmptyRow('Sin ventas en este día');
    }

    final activas = metrics.sales.where((s) => !s.anulada).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final preview = activas.take(5).toList();

    return Column(
      children: [
        ...preview.map(
          (sale) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VentaTile(sale: sale),
          ),
        ),
        if (activas.length > preview.length)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'y ${activas.length - preview.length} más…',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onVerTodos,
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(
              'Ver comprobantes (${metrics.saleCount})',
            ),
          ),
        ),
      ],
    );
  }
}

class _VentaTile extends StatelessWidget {
  const _VentaTile({required this.sale});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    final t = sale.createdAt;
    final hora =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            hora,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.clienteNombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sale.sellerName?.isNotEmpty ?? false)
                  Text(
                    sale.sellerName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (sale.collectedArs > 0)
                Text(
                  formatArs(sale.collectedArs),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (sale.collectedUsd > 0)
                Text(
                  formatUsd(sale.collectedUsd),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockAlCierreCard extends StatelessWidget {
  const _StockAlCierreCard({required this.stock});

  final StockAlCierre stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StockStat(
                label: 'Productos',
                value: '${stock.productosConStock}',
                icon: Icons.inventory_2_outlined,
              ),
              _StockStat(
                label: 'Cajas',
                value: '${stock.cajasMunicion}',
                icon: Icons.inventory_outlined,
              ),
              _StockStat(
                label: 'Balas',
                value: '${stock.balasMunicion}',
                icon: Icons.local_fire_department_outlined,
              ),
              _StockStat(
                label: 'Armas',
                value: '${stock.unidadesArmas}',
                icon: Icons.shield_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Totales del inventario actual, sin listar cada producto.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockStat extends StatelessWidget {
  const _StockStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CierreLineCard extends StatelessWidget {
  const _CierreLineCard({required this.line});

  final CierreLine line;

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final label = p.isArma
        ? '${p.marcaUpper} ${p.modeloDisplay}'
        : '${p.marcaUpper} ${p.codigo}';
    final muni = line.isMunicion && line.roundsPerBox != null;

    String cell(int cajas, int? balas) {
      if (muni && balas != null) return '$cajas cajas\n$balas balas';
      return '$cajas u.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (p.descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              p.descripcion,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniCell(
                label: 'Apertura',
                value: cell(line.aperturaCajas, line.aperturaBalas),
              ),
              _arrow(),
              _MiniCell(
                label: 'Vendido',
                value: cell(line.vendidoCajas, line.vendidoBalas),
                highlight: true,
              ),
              _arrow(),
              _MiniCell(
                label: 'Cierre',
                value: cell(line.cierreCajas, line.cierreBalas),
              ),
            ],
          ),
          if (line.cargaCajas != 0 || line.ajusteCajas != 0) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (line.cargaCajas != 0) 'Carga: +${line.cargaCajas}',
                if (line.ajusteCajas != 0)
                  'Ajuste: ${line.ajusteCajas > 0 ? '+' : ''}${line.ajusteCajas}',
              ].join('   ·   '),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.goldDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.chevron_right_rounded,
            color: AppColors.textSecondary, size: 20),
      );
}

class _MiniCell extends StatelessWidget {
  const _MiniCell({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.danger),
      ),
    );
  }
}
