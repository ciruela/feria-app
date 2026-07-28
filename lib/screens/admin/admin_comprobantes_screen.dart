import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/sale_record.dart';
import '../../services/catalog_service.dart';
import '../../services/comprobante_pdf_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

/// Listado de comprobantes emitidos en un día (ver / compartir PDF).
class AdminComprobantesScreen extends StatefulWidget {
  const AdminComprobantesScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AdminComprobantesScreen> createState() =>
      _AdminComprobantesScreenState();
}

class _AdminComprobantesScreenState extends State<AdminComprobantesScreen> {
  SalesMetricsService? _service;
  late DateTime _selectedDay;
  List<SaleRecord> _sales = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate ?? DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= SalesMetricsService(
      catalog: context.read<CatalogService>(),
    );
    if (!_loading && _sales.isEmpty && _error == null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!AppConfig.useSupabase) return;

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
        _sales = metrics.sales;
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

  Future<void> _voidSale(SaleRecord sale) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _VoidReasonDialog(),
    );
    if (motivo == null) return;

    setState(() => _loading = true);
    try {
      final service = _service;
      if (service == null) return;
      final ok = await service.voidSale(
        sale,
        motivo: motivo,
        actorNombre: 'Admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Venta anulada y stock restituido' : 'La venta ya estaba anulada',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular: $error')),
      );
    }
  }

  void _openDetail(SaleRecord sale) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminComprobanteDetailScreen(
          sale: sale,
          onVoid: sale.anulada ? null : () => _voidSale(sale),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._sales]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Comprobantes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !AppConfig.useSupabase
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Los comprobantes en la nube requieren Supabase.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  _DateChip(date: _selectedDay, onTap: _pickDate),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: '${sorted.length} comprobante${sorted.length == 1 ? '' : 's'}',
                    subtitle: 'Tocá uno para ver detalle, PDF o compartir',
                  ),
                  const SizedBox(height: 12),
                  if (_loading && sorted.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (sorted.isEmpty)
                    const _EmptyComprobantes()
                  else
                    ...sorted.map(
                      (sale) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ComprobanteListTile(
                          sale: sale,
                          onTap: () => _openDetail(sale),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class AdminComprobanteDetailScreen extends StatefulWidget {
  const AdminComprobanteDetailScreen({
    super.key,
    required this.sale,
    this.onVoid,
  });

  final SaleRecord sale;
  final VoidCallback? onVoid;

  @override
  State<AdminComprobanteDetailScreen> createState() =>
      _AdminComprobanteDetailScreenState();
}

class _AdminComprobanteDetailScreenState
    extends State<AdminComprobanteDetailScreen> {
  final _pdfService = ComprobantePdfService();
  late SaleRecord _sale;
  String? _pdfPathOverride;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
  }

  SaleRecord get _effectiveSale {
    final path = _pdfPathOverride ?? _sale.pdfPath;
    if (path == _sale.pdfPath) return _sale;
    return SaleRecord(
      id: _sale.id,
      createdAt: _sale.createdAt,
      lines: _sale.lines,
      sellerName: _sale.sellerName,
      vendedorId: _sale.vendedorId,
      totalArs: _sale.totalArs,
      totalUsd: _sale.totalUsd,
      clienteNombre: _sale.clienteNombre,
      clienteDni: _sale.clienteDni,
      pdfPath: path,
      anulada: _sale.anulada,
      anuladaMotivo: _sale.anuladaMotivo,
      anuladaPor: _sale.anuladaPor,
      anuladaAt: _sale.anuladaAt,
      customerDetail: _sale.customerDetail,
      saleDate: _sale.saleDate,
    );
  }

  Future<void> _viewPdf() async {
    setState(() => _pdfBusy = true);
    try {
      await _pdfService.viewSalePdf(_effectiveSale);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _pdfBusy = true);
    try {
      await _pdfService.shareSalePdf(_effectiveSale);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _savePdfToCloud() async {
    setState(() => _pdfBusy = true);
    try {
      final path = await _pdfService.ensureStoredForSale(_effectiveSale);
      if (!mounted) return;
      setState(() => _pdfPathOverride = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF guardado en la nube')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _effectiveSale;
    final time = TimeOfDay.fromDateTime(sale.createdAt);
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: Text(sale.clienteNombre.trim().isEmpty ? 'Comprobante' : sale.clienteNombre.trim()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          if (sale.anulada) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: Text(
                'ANULADA · ${sale.anuladaMotivo.trim().isEmpty ? 'sin motivo' : sale.anuladaMotivo.trim()}',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _InfoRow(label: 'Fecha', value: '${formatDate(sale.createdAt)} · $timeLabel'),
          if (sale.clienteDni.trim().isNotEmpty)
            _InfoRow(label: 'DNI', value: sale.clienteDni.trim()),
          if (sale.sellerName != null && sale.sellerName!.trim().isNotEmpty)
            _InfoRow(label: 'Vendedor', value: sale.sellerName!.trim()),
          _InfoRow(
            label: 'Total ARS',
            value: sale.collectedArs > 0 ? formatArs(sale.collectedArs) : '—',
          ),
          _InfoRow(
            label: 'Total USD',
            value: sale.collectedUsd > 0 ? formatUsd(sale.collectedUsd) : '—',
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Ítems',
            subtitle: 'Detalle guardado de la venta',
          ),
          const SizedBox(height: 10),
          ...sale.lines.map(
            (line) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.detail.isNotEmpty
                        ? line.detail
                        : (line.code.isNotEmpty ? line.code : 'Ítem'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cant: ${line.quantity} · '
                    '${line.paysInUsd ? formatUsd(line.lineUsd) : formatArs(line.lineArs)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pdfBusy ? null : _viewPdf,
            icon: _pdfBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(sale.hasPdf ? 'VER PDF' : 'VER PDF (regenerado)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pdfBusy ? null : _sharePdf,
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('COMPARTIR / DESCARGAR PDF'),
          ),
          if (!sale.hasPdf) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pdfBusy ? null : _savePdfToCloud,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('GUARDAR PDF EN LA NUBE'),
            ),
            const SizedBox(height: 8),
            const Text(
              'El PDF no se subió al emitir la venta. Podés verlo igual '
              'regenerándolo desde los datos guardados, o intentar guardarlo en la nube.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
          if (widget.onVoid != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onVoid,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.block_rounded),
              label: const Text('ANULAR VENTA'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: AppColors.goldDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isToday ? 'Hoy · ${formatDate(date)}' : formatDate(date),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ComprobanteListTile extends StatelessWidget {
  const _ComprobanteListTile({required this.sale, required this.onTap});

  final SaleRecord sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(sale.createdAt);
    final timeLabel =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final client =
        sale.clienteNombre.trim().isEmpty ? 'Sin nombre' : sale.clienteNombre.trim();
    final totalParts = <String>[];
    if (sale.collectedArs > 0) totalParts.add(formatArs(sale.collectedArs));
    if (sale.collectedUsd > 0) totalParts.add(formatUsd(sale.collectedUsd));
    final totalLabel = totalParts.isEmpty ? 'Sin importe' : totalParts.join(' · ');

    return Material(
      color: sale.anulada
          ? AppColors.danger.withValues(alpha: 0.06)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sale.anulada
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  sale.hasPdf ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration:
                            sale.anulada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(
                      '$timeLabel · $totalLabel · ${sale.lines.length} ítem${sale.lines.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (sale.anulada)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                    ),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyComprobantes extends StatelessWidget {
  const _EmptyComprobantes();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'No hay comprobantes este día',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando generés una venta desde el carrito aparecerá acá.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
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
            'Se restituirá el stock y quedará registrado en la auditoría.',
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
