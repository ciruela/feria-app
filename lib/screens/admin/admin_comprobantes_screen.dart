import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../models/sale_record.dart';
import '../../services/catalog_service.dart';
import '../../services/comprobante_pdf_service.dart';
import '../../services/sales_metrics_service.dart';
import '../../services/stock_cierre_service.dart';
import '../../services/supabase_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/presupuesto/presupuesto_paper.dart';
import '../../utils/formatters.dart';
import '../../widgets/admin_date_filter.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

enum _FacturadaFilter { todos, pendientes, facturados }

/// Listado de comprobantes con control de facturación AFIP.
class AdminComprobantesScreen extends StatefulWidget {
  const AdminComprobantesScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<AdminComprobantesScreen> createState() =>
      _AdminComprobantesScreenState();
}

class _AdminComprobantesScreenState extends State<AdminComprobantesScreen> {
  SalesMetricsService? _service;
  final _exportService = StockCierreService();
  RealtimeChannel? _realtimeChannel;

  late DateTime _selectedDay;
  DateTime? _rangeFrom;
  DateTime? _rangeTo;
  AdminDateMode _dateMode = AdminDateMode.dia;
  _FacturadaFilter _filter = _FacturadaFilter.todos;

  List<SaleRecord> _sales = const [];
  bool _loading = false;
  bool _exporting = false;
  bool _realtimeStarted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate ?? DateTime.now();
    _rangeFrom = _selectedDay;
    _rangeTo = _selectedDay;
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
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    if (_realtimeStarted || !SupabaseService.isConfigured) return;
    _realtimeStarted = true;
    _realtimeChannel = SupabaseService.client
        .channel('public:ventas-comprobantes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ventas',
          callback: (_) => _load(silent: true),
        )
        .subscribe();
  }

  DateTime get _queryStart {
    if (_dateMode == AdminDateMode.dia) {
      return DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    }
    final from = _rangeFrom ?? _selectedDay;
    return DateTime(from.year, from.month, from.day);
  }

  DateTime get _queryEnd {
    if (_dateMode == AdminDateMode.dia) {
      return _queryStart.add(const Duration(days: 1));
    }
    final to = _rangeTo ?? _rangeFrom ?? _selectedDay;
    return DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
  }

  List<SaleRecord> get _filteredSales {
    return _sales.where((sale) {
      switch (_filter) {
        case _FacturadaFilter.todos:
          return true;
        case _FacturadaFilter.pendientes:
          return sale.pendienteFacturacion;
        case _FacturadaFilter.facturados:
          return !sale.anulada && sale.facturada;
      }
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  _FacturacionResumen get _resumen {
    var activas = 0;
    var facturadas = 0;
    var pendientes = 0;
    var pendientesArs = 0.0;
    var pendientesUsd = 0.0;

    for (final sale in _sales) {
      if (sale.anulada) continue;
      activas++;
      if (sale.facturada) {
        facturadas++;
      } else {
        pendientes++;
        pendientesArs += sale.collectedArs;
        pendientesUsd += sale.collectedUsd;
      }
    }

    return _FacturacionResumen(
      activas: activas,
      facturadas: facturadas,
      pendientes: pendientes,
      pendientesArs: pendientesArs,
      pendientesUsd: pendientesUsd,
    );
  }

  Future<void> _load({bool silent = false}) async {
    if (!AppConfig.useSupabase) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final service = _service;
      if (service == null) return;
      final sales = await service.salesForRange(_queryStart, _queryEnd);
      if (!mounted) return;
      setState(() {
        _sales = sales;
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

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedDay = picked;
      _rangeFrom = picked;
      _rangeTo = picked;
    });
    await _load();
  }

  Future<void> _pickRange({required bool isFrom}) async {
    final initial = isFrom
        ? (_rangeFrom ?? _selectedDay)
        : (_rangeTo ?? _rangeFrom ?? _selectedDay);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _rangeFrom = picked;
        if (_rangeTo != null && picked.isAfter(_rangeTo!)) {
          _rangeTo = picked;
        }
      } else {
        _rangeTo = picked;
        if (_rangeFrom != null && picked.isBefore(_rangeFrom!)) {
          _rangeFrom = picked;
        }
      }
    });
    await _load();
  }

  Future<void> _setFacturada(
    SaleRecord sale, {
    required bool facturada,
    String? facturaNumero,
  }) async {
    final service = _service;
    if (service == null) return;

    try {
      final ok = await service.setFacturada(
        sale,
        facturada: facturada,
        facturaNumero: facturaNumero,
        actorNombre: 'Admin',
      );
      if (!ok || !mounted) return;
      setState(() {
        _sales = [
          for (final item in _sales)
            if (item.id == sale.id)
              _copySale(
                item,
                facturada: facturada,
                facturaNumero: facturaNumero ?? '',
                facturadaPor: facturada ? 'Admin' : '',
                facturadaAt: facturada ? DateTime.now() : null,
              )
            else
              item,
        ];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
    }
  }

  Future<void> _markVisibleFacturados() async {
    final pending = _filteredSales.where((s) => s.pendienteFacturacion).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comprobantes pendientes en esta vista')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Marcar como facturados'),
        content: Text(
          '¿Marcar ${pending.length} comprobante${pending.length == 1 ? '' : 's'} '
          'como facturado${pending.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final service = _service;
      if (service == null) return;
      final count = await service.setFacturadaBatch(
        pending,
        facturada: true,
        actorNombre: 'Admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count marcado${count == 1 ? '' : 's'} como facturado${count == 1 ? '' : 's'}')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  Future<void> _exportVisible() async {
    final sales = _filteredSales;
    if (sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comprobantes para exportar')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final bytes = _exportService.exportVentasList(sales);
      final stamp = _fileStamp();
      await FilePicker.saveFile(
        fileName: 'comprobantes_$stamp.xlsx',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobantes exportados')),
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

  String _fileStamp() {
    if (_dateMode == AdminDateMode.dia) {
      final d = _selectedDay;
      return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    }
    final from = _rangeFrom ?? _selectedDay;
    final to = _rangeTo ?? from;
    String part(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '${part(from)}_${part(to)}';
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

  Future<void> _openDetail(SaleRecord sale) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminComprobanteDetailScreen(
          sale: sale,
          onVoid: sale.anulada ? null : () => _voidSale(sale),
          onSetFacturada: sale.anulada
              ? null
              : ({required facturada, facturaNumero}) => _setFacturada(
                    sale,
                    facturada: facturada,
                    facturaNumero: facturaNumero,
                  ),
        ),
      ),
    );
    await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _filteredSales;
    final resumen = _resumen;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Comprobantes'),
        actions: [
          IconButton(
            tooltip: 'Exportar Excel',
            onPressed: _exporting || sorted.isEmpty ? null : _exportVisible,
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
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
                  AdminDateModeSelector(
                    mode: _dateMode,
                    onChanged: (mode) {
                      setState(() => _dateMode = mode);
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_dateMode == AdminDateMode.dia)
                    AdminDateChip(date: _selectedDay, onTap: _pickDay)
                  else
                    AdminRangeChips(
                      from: _rangeFrom ?? _selectedDay,
                      to: _rangeTo ?? _rangeFrom ?? _selectedDay,
                      onPickFrom: () => _pickRange(isFrom: true),
                      onPickTo: () => _pickRange(isFrom: false),
                    ),
                  const SizedBox(height: 12),
                  _FacturacionSummary(resumen: resumen),
                  const SizedBox(height: 12),
                  _FacturadaFilterBar(
                    filter: _filter,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                  if (resumen.pendientes > 0 &&
                      _filter != _FacturadaFilter.facturados) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _loading ? null : _markVisibleFacturados,
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('Marcar visibles como facturados'),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: '${sorted.length} comprobante${sorted.length == 1 ? '' : 's'}',
                    subtitle: 'Tildá facturado cuando emitas la factura AFIP',
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
                          onFacturadaChanged: sale.anulada
                              ? null
                              : (value) => _setFacturada(sale, facturada: value),
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
    this.onSetFacturada,
  });

  final SaleRecord sale;
  final VoidCallback? onVoid;
  final Future<void> Function({
    required bool facturada,
    String? facturaNumero,
  })? onSetFacturada;

  @override
  State<AdminComprobanteDetailScreen> createState() =>
      _AdminComprobanteDetailScreenState();
}

class _AdminComprobanteDetailScreenState
    extends State<AdminComprobanteDetailScreen> {
  final _pdfService = ComprobantePdfService();
  final _facturaNumeroController = TextEditingController();
  late SaleRecord _sale;
  String? _pdfPathOverride;
  bool _pdfBusy = false;
  bool _facturadaBusy = false;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
    _facturaNumeroController.text = _sale.facturaNumero;
  }

  @override
  void dispose() {
    _facturaNumeroController.dispose();
    super.dispose();
  }

  SaleRecord get _effectiveSale {
    final path = _pdfPathOverride ?? _sale.pdfPath;
    if (path == _sale.pdfPath) return _sale;
    return _copySale(_sale, pdfPath: path);
  }

  Future<void> _toggleFacturada(bool value) async {
    final callback = widget.onSetFacturada;
    if (callback == null) return;

    setState(() => _facturadaBusy = true);
    try {
      await callback(
        facturada: value,
        facturaNumero: value ? _facturaNumeroController.text : null,
      );
      if (!mounted) return;
      setState(() {
        _sale = _copySale(
          _sale,
          facturada: value,
          facturaNumero: value ? _facturaNumeroController.text.trim() : '',
          facturadaPor: value ? 'Admin' : '',
          facturadaAt: value ? DateTime.now() : null,
        );
      });
    } finally {
      if (mounted) setState(() => _facturadaBusy = false);
    }
  }

  Future<void> _viewPdf() async {
    setState(() => _pdfBusy = true);
    try {
      final branding = resolvePresupuestoBranding(
        context.read<TenantSessionService>(),
      );
      await _pdfService.viewSalePdf(_effectiveSale, branding: branding);
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
      final branding = resolvePresupuestoBranding(
        context.read<TenantSessionService>(),
      );
      await _pdfService.shareSalePdf(_effectiveSale, branding: branding);
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
      final branding = resolvePresupuestoBranding(
        context.read<TenantSessionService>(),
      );
      final path = await _pdfService.ensureStoredForSale(
        _effectiveSale,
        branding: branding,
      );
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

  /// Bloque de texto con los datos del cliente para pegar en el otro software.
  String _customerBlock(SaleRecord sale) {
    final cust = sale.customerDetail;
    final name = cust.fullName.trim().isNotEmpty
        ? cust.fullName.trim()
        : sale.clienteNombre.trim();
    final dni =
        cust.dni.trim().isNotEmpty ? cust.dni.trim() : sale.clienteDni.trim();

    final lines = <String>[];
    if (name.isNotEmpty) lines.add(name);
    if (dni.isNotEmpty) lines.add('DNI/CUIT: $dni');
    if (cust.fiscalCondition.trim().isNotEmpty) {
      lines.add('Cond. fiscal: ${cust.fiscalCondition.trim()}');
    }
    if (cust.clu.trim().isNotEmpty) lines.add('CLU: ${cust.clu.trim()}');
    if (cust.domicilioLine.isNotEmpty) {
      lines.add('Domicilio: ${cust.domicilioLine}');
    }
    if (cust.phone.trim().isNotEmpty) lines.add('Tel: ${cust.phone.trim()}');
    if (cust.email.trim().isNotEmpty) lines.add('Email: ${cust.email.trim()}');
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final sale = _effectiveSale;
    final cust = sale.customerDetail;
    final clientName = cust.fullName.trim().isNotEmpty
        ? cust.fullName.trim()
        : sale.clienteNombre.trim();
    final clientDni =
        cust.dni.trim().isNotEmpty ? cust.dni.trim() : sale.clienteDni.trim();
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
          if (!sale.anulada && widget.onSetFacturada != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sale.facturada
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sale.facturada
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Facturada (AFIP)',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      sale.facturada
                          ? 'Marcada por ${sale.facturadaPor.isEmpty ? 'admin' : sale.facturadaPor}'
                          : 'Pendiente de facturación',
                    ),
                    value: sale.facturada,
                    onChanged: _facturadaBusy ? null : _toggleFacturada,
                  ),
                  TextField(
                    controller: _facturaNumeroController,
                    enabled: !sale.facturada && !_facturadaBusy,
                    decoration: const InputDecoration(
                      labelText: 'Nº factura (opcional)',
                      hintText: 'Ej: 0001-00001234',
                    ),
                    onSubmitted: (_) {
                      if (!sale.facturada) _toggleFacturada(true);
                    },
                  ),
                  if (sale.facturada && sale.facturadaAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Marcada ${formatDateTime(sale.facturadaAt!)}'
                      '${sale.facturaNumero.isNotEmpty ? ' · ${sale.facturaNumero}' : ''}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _InfoRow(label: 'Fecha', value: '${formatDate(sale.createdAt)} · $timeLabel'),
          if (clientName.isNotEmpty)
            _InfoRow(label: 'Cliente', value: clientName),
          if (clientDni.isNotEmpty)
            _InfoRow(label: 'DNI/CUIT', value: clientDni),
          if (cust.fiscalCondition.trim().isNotEmpty)
            _InfoRow(label: 'Cond. fiscal', value: cust.fiscalCondition.trim()),
          if (cust.clu.trim().isNotEmpty)
            _InfoRow(label: 'CLU', value: cust.clu.trim()),
          if (cust.address.trim().isNotEmpty)
            _InfoRow(label: 'Domicilio', value: cust.address.trim()),
          if (cust.city.trim().isNotEmpty)
            _InfoRow(label: 'Ciudad', value: cust.city.trim()),
          if (cust.phone.trim().isNotEmpty)
            _InfoRow(label: 'Teléfono', value: cust.phone.trim()),
          if (cust.email.trim().isNotEmpty)
            _InfoRow(label: 'Email', value: cust.email.trim()),
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
          if (sale.facturaNumero.trim().isNotEmpty)
            _InfoRow(label: 'Nº factura', value: sale.facturaNumero.trim()),
          if (_customerBlock(sale).isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => copyToClipboard(
                context,
                _customerBlock(sale),
                label: 'Datos del cliente',
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('COPIAR DATOS DEL CLIENTE'),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Ítems',
            subtitle: 'Detalle guardado de la venta',
          ),
          const SizedBox(height: 10),
          ...sale.lines.map((line) {
            final title = line.detail.isNotEmpty
                ? line.detail
                : (line.code.isNotEmpty ? line.code : 'Ítem');
            final amount = line.paysInUsd
                ? formatUsd(line.lineUsd)
                : formatArs(line.lineArs);
            final hasSerial = line.serialNumber.trim().isNotEmpty;

            final copyParts = <String>[title];
            if (line.code.isNotEmpty && line.code != title) {
              copyParts.add('Cód: ${line.code}');
            }
            copyParts.add('Cant: ${line.quantity}');
            copyParts.add(amount);
            if (hasSerial) copyParts.add('Serie: ${line.serialNumber.trim()}');

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (line.code.isNotEmpty && line.code != title) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Cód: ${line.code}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Cant: ${line.quantity} · $amount',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (hasSerial) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Serie: ${line.serialNumber.trim()}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copiar ítem',
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    color: AppColors.textSecondary,
                    onPressed: () => copyToClipboard(
                      context,
                      copyParts.join(' · '),
                      label: 'Ítem',
                    ),
                  ),
                ],
              ),
            );
          }),
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

class _FacturacionResumen {
  const _FacturacionResumen({
    required this.activas,
    required this.facturadas,
    required this.pendientes,
    required this.pendientesArs,
    required this.pendientesUsd,
  });

  final int activas;
  final int facturadas;
  final int pendientes;
  final double pendientesArs;
  final double pendientesUsd;
}

class _FacturacionSummary extends StatelessWidget {
  const _FacturacionSummary({required this.resumen});

  final _FacturacionResumen resumen;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (resumen.pendientesArs > 0) {
      parts.add(formatArs(resumen.pendientesArs));
    }
    if (resumen.pendientesUsd > 0) {
      parts.add(formatUsd(resumen.pendientesUsd));
    }
    final pendienteLabel =
        parts.isEmpty ? '—' : parts.join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Facturación',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryChip(
                label: 'Total',
                value: '${resumen.activas}',
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Facturadas',
                value: '${resumen.facturadas}',
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Pendientes',
                value: '${resumen.pendientes}',
                color: resumen.pendientes > 0 ? AppColors.goldDark : null,
              ),
            ],
          ),
          if (resumen.pendientes > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Pendiente de facturar: $pendienteLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacturadaFilterBar extends StatelessWidget {
  const _FacturadaFilterBar({required this.filter, required this.onChanged});

  final _FacturadaFilter filter;
  final ValueChanged<_FacturadaFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Todos'),
          selected: filter == _FacturadaFilter.todos,
          onSelected: (_) => onChanged(_FacturadaFilter.todos),
        ),
        ChoiceChip(
          label: const Text('Pendientes'),
          selected: filter == _FacturadaFilter.pendientes,
          onSelected: (_) => onChanged(_FacturadaFilter.pendientes),
        ),
        ChoiceChip(
          label: const Text('Facturados'),
          selected: filter == _FacturadaFilter.facturados,
          onSelected: (_) => onChanged(_FacturadaFilter.facturados),
        ),
      ],
    );
  }
}

class _ComprobanteListTile extends StatelessWidget {
  const _ComprobanteListTile({
    required this.sale,
    required this.onTap,
    this.onFacturadaChanged,
  });

  final SaleRecord sale;
  final VoidCallback onTap;
  final ValueChanged<bool>? onFacturadaChanged;

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
          : sale.facturada
              ? AppColors.success.withValues(alpha: 0.05)
              : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sale.anulada
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : sale.facturada
                      ? AppColors.success.withValues(alpha: 0.35)
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              if (onFacturadaChanged != null)
                Checkbox(
                  value: sale.facturada,
                  onChanged: (value) {
                    if (value != null) onFacturadaChanged!(value);
                  },
                )
              else if (sale.anulada)
                const SizedBox(width: 12),
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
                    if (sale.facturada && sale.facturaNumero.isNotEmpty)
                      Text(
                        'Factura ${sale.facturaNumero}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
              else if (sale.facturada)
                const Icon(Icons.check_circle_rounded, color: AppColors.success)
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Copia [text] al portapapeles y avisa (para pegar en el otro software).
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  String? label,
}) async {
  final value = text.trim();
  if (value.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 1),
      content: Text(label == null ? 'Copiado' : '$label copiado'),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final canCopy = value.trim().isNotEmpty && value.trim() != '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (canCopy)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Copiar $label',
              icon: const Icon(Icons.copy_rounded, size: 16),
              color: AppColors.textSecondary,
              onPressed: () => copyToClipboard(context, value, label: label),
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
            'No hay comprobantes en este período',
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

SaleRecord _copySale(
  SaleRecord sale, {
  String? pdfPath,
  bool? facturada,
  String? facturadaPor,
  DateTime? facturadaAt,
  String? facturaNumero,
}) {
  return SaleRecord(
    id: sale.id,
    createdAt: sale.createdAt,
    lines: sale.lines,
    sellerName: sale.sellerName,
    vendedorId: sale.vendedorId,
    totalArs: sale.totalArs,
    totalUsd: sale.totalUsd,
    clienteNombre: sale.clienteNombre,
    clienteDni: sale.clienteDni,
    pdfPath: pdfPath ?? sale.pdfPath,
    anulada: sale.anulada,
    anuladaMotivo: sale.anuladaMotivo,
    anuladaPor: sale.anuladaPor,
    anuladaAt: sale.anuladaAt,
    facturada: facturada ?? sale.facturada,
    facturadaPor: facturadaPor ?? sale.facturadaPor,
    facturadaAt: facturadaAt ?? sale.facturadaAt,
    facturaNumero: facturaNumero ?? sale.facturaNumero,
    customerDetail: sale.customerDetail,
    saleDate: sale.saleDate,
  );
}
