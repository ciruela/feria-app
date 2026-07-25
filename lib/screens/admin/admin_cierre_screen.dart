import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/catalog_service.dart';
import '../../services/stock_cierre_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

class AdminCierreScreen extends StatefulWidget {
  const AdminCierreScreen({super.key});

  @override
  State<AdminCierreScreen> createState() => _AdminCierreScreenState();
}

class _AdminCierreScreenState extends State<AdminCierreScreen> {
  final _service = StockCierreService();
  DateTime _selectedDay = DateTime.now();
  CierreResumen? _resumen;
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useSupabase) {
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
      final resumen = await _service.cierreForDay(_selectedDay, products);
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
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
    if (resumen == null) return;

    setState(() => _exporting = true);
    try {
      final bytes = _service.exportToExcel(resumen);
      final stamp = DateFormatCompat.file(_selectedDay);
      await FilePicker.saveFile(
        fileName: 'cierre_$stamp.xlsx',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre exportado')),
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
              label: const Text('EXPORTAR'),
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
                      if (_resumen != null) ...[
                        const SizedBox(height: 20),
                        _TotalsCard(resumen: _resumen!),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Munición',
                          subtitle: 'Apertura → vendido → cierre (cajas y balas)',
                        ),
                        const SizedBox(height: 12),
                        ..._municionLines(_resumen!),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          title: 'Armas',
                          subtitle: 'Apertura → vendido → cierre (unidades)',
                        ),
                        const SizedBox(height: 12),
                        ..._armasLines(_resumen!),
                      ],
                    ],
                  ),
                ),
    );
  }

  List<Widget> _municionLines(CierreResumen resumen) {
    final lines = resumen.municion.toList();
    if (lines.isEmpty) {
      return [const _EmptyRow('Sin munición con stock')];
    }
    return lines
        .map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CierreLineCard(line: line),
            ))
        .toList();
  }

  List<Widget> _armasLines(CierreResumen resumen) {
    final lines = resumen.armas.toList();
    if (lines.isEmpty) {
      return [const _EmptyRow('Sin armas con stock')];
    }
    return lines
        .map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CierreLineCard(line: line),
            ))
        .toList();
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

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.resumen});

  final CierreResumen resumen;

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
            'VENDIDO EN EL DÍA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TotalCell(
                label: 'Balas',
                value: '${resumen.totalBalasVendidas}',
              ),
              _TotalCell(
                label: 'Cajas',
                value: '${resumen.totalCajasVendidas}',
              ),
              _TotalCell(
                label: 'Armas',
                value: '${resumen.totalArmasVendidas}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Quedan en munición: ${resumen.totalBalasCierre} balas',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            style: const TextStyle(
              fontSize: 13,
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
          color: line.tieneActividad
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
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
              _MiniCell(label: 'Apertura', value: cell(line.aperturaCajas, line.aperturaBalas)),
              _arrow(),
              _MiniCell(
                label: 'Vendido',
                value: cell(line.vendidoCajas, line.vendidoBalas),
                highlight: true,
              ),
              _arrow(),
              _MiniCell(label: 'Cierre', value: cell(line.cierreCajas, line.cierreBalas)),
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
