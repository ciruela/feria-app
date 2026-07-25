import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/audit_entry.dart';
import '../../services/audit_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  DateTime? _day = DateTime.now();
  String? _entidadFilter;
  late Future<List<AuditEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AuditEntry>> _load() {
    final day = _day;
    if (day == null) {
      return AuditService.instance.fetchRecent();
    }
    return AuditService.instance.fetchForDay(day);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _day = picked);
    await _refresh();
  }

  List<AuditEntry> _applyEntidad(List<AuditEntry> entries) {
    if (_entidadFilter == null) return entries;
    return entries.where((e) => e.entidad == _entidadFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useSupabase) {
      return const FeriaScaffold(
        appBar: FeriaAppBar(title: Text('Registro de actividad')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'El registro de actividad requiere Supabase configurado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Registro de actividad'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            day: _day,
            onPickDate: _pickDate,
            onRecent: () {
              setState(() => _day = null);
              _refresh();
            },
            onToday: () {
              setState(() => _day = DateTime.now());
              _refresh();
            },
          ),
          _EntidadChips(
            selected: _entidadFilter,
            onSelected: (value) => setState(() => _entidadFilter = value),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<AuditEntry>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text('Error: ${snapshot.error}',
                              textAlign: TextAlign.center),
                        ),
                      ],
                    );
                  }

                  final entries = _applyEntidad(snapshot.data ?? const []);
                  if (entries.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Sin actividad registrada',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ActivityTile(entry: entries[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.day,
    required this.onPickDate,
    required this.onRecent,
    required this.onToday,
  });

  final DateTime? day;
  final VoidCallback onPickDate;
  final VoidCallback onRecent;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(day == null ? 'Elegir fecha' : formatDate(day!)),
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Hoy'),
            selected: day != null && _isToday(day!),
            onSelected: (_) => onToday(),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('Recientes'),
            selected: day == null,
            onSelected: (_) => onRecent(),
          ),
        ],
      ),
    );
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _EntidadChips extends StatelessWidget {
  const _EntidadChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Todo'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
            ),
            ...AuditEntidad.all.map(
              (entidad) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(AuditEntidad.label(entidad)),
                  selected: selected == entidad,
                  onSelected: (_) =>
                      onSelected(selected == entidad ? null : entidad),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});

  final AuditEntry entry;

  Color get _color {
    switch (entry.entidad) {
      case AuditEntidad.producto:
        return AppColors.primary;
      case AuditEntidad.precio:
      case AuditEntidad.tipoCambio:
        return AppColors.accent;
      case AuditEntidad.vendedor:
        return AppColors.armaCorta;
      case AuditEntidad.venta:
        return AppColors.success;
      case AuditEntidad.excel:
        return AppColors.armaLarga;
      case AuditEntidad.administrador:
      case AuditEntidad.acceso:
        return AppColors.goldDark;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.accion,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (entry.detalle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.detalle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${entry.actorNombre.isEmpty ? 'Sistema' : entry.actorNombre}'
                  ' · ${formatDateTime(entry.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
