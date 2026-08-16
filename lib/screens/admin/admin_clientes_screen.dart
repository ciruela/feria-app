import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/customer_record.dart';
import '../../services/customer_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import 'admin_cliente_edit_screen.dart';

class AdminClientesScreen extends StatefulWidget {
  const AdminClientesScreen({super.key});

  @override
  State<AdminClientesScreen> createState() => _AdminClientesScreenState();
}

class _AdminClientesScreenState extends State<AdminClientesScreen> {
  final _repository = CustomerRepository();
  final _searchController = TextEditingController();
  List<CustomerRecord> _clientes = const [];
  bool _loading = false;
  String? _error;

  ClientesSort _sort = ClientesSort.recent;
  bool _onlyWithSales = false;
  String _fiscal = '';
  List<String> _fiscalOptions = const [];
  DateTime? _from;
  DateTime? _to;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFiscalOptions();
  }

  Future<void> _loadFiscalOptions() async {
    if (!AppConfig.useSupabase) return;
    final options = await _repository.fiscalConditions();
    if (!mounted) return;
    setState(() => _fiscalOptions = options);
  }

  bool get _hasActiveFilters =>
      _onlyWithSales ||
      _fiscal.isNotEmpty ||
      _from != null ||
      _to != null ||
      _sort != ClientesSort.recent;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Búsqueda en vivo: recarga con un pequeño debounce mientras se tipea.
  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!AppConfig.useSupabase) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _repository.list(
        query: _searchController.text,
        sort: _sort,
        onlyWithSales: _onlyWithSales,
        fiscalCondition: _fiscal,
        lastSaleFrom: _from,
        lastSaleTo: _to,
      );
      if (!mounted) return;
      setState(() {
        _clientes = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openCliente(CustomerRecord record) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminClienteEditScreen(
          clienteId: record.id,
          initial: record,
        ),
      ),
    );
    if (updated == true) {
      await _load();
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _from : _to) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = DateTime(picked.year, picked.month, picked.day);
      } else {
        _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
    _load();
  }

  void _clearFilters() {
    _debounce?.cancel();
    setState(() {
      _searchController.clear();
      _sort = ClientesSort.recent;
      _onlyWithSales = false;
      _fiscal = '';
      _from = null;
      _to = null;
    });
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _filterDropdown<T>({
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _filterDropdown<ClientesSort>(
          icon: Icons.sort_rounded,
          value: _sort,
          items: [
            for (final s in ClientesSort.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _sort = v);
            _load();
          },
        ),
        FilterChip(
          label: const Text('Con compras'),
          selected: _onlyWithSales,
          onSelected: (v) {
            setState(() => _onlyWithSales = v);
            _load();
          },
        ),
        if (_fiscalOptions.isNotEmpty)
          _filterDropdown<String>(
            icon: Icons.receipt_long_rounded,
            value: _fiscal,
            items: [
              const DropdownMenuItem(value: '', child: Text('Cond. fiscal: todas')),
              for (final f in _fiscalOptions)
                DropdownMenuItem(value: f, child: Text(f)),
            ],
            onChanged: (v) {
              setState(() => _fiscal = v ?? '');
              _load();
            },
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(_from == null ? 'Desde' : 'Desde ${_fmtDate(_from!)}'),
          onPressed: () => _pickDate(isFrom: true),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.event_rounded, size: 16),
          label: Text(_to == null ? 'Hasta' : 'Hasta ${_fmtDate(_to!)}'),
          onPressed: () => _pickDate(isFrom: false),
        ),
        TextButton.icon(
          icon: const Icon(Icons.clear_all_rounded, size: 16),
          label: const Text('Limpiar filtros'),
          onPressed:
              (_hasActiveFilters || _searchController.text.trim().isNotEmpty)
                  ? _clearFilters
                  : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            if (!AppConfig.useSupabase)
              const _InfoBanner(
                message: 'Configurá Supabase para ver la base de clientes.',
              ),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Buscar por apellido, DNI, teléfono, mail o ciudad',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _debounce?.cancel();
                          _searchController.clear();
                          _load();
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onSubmitted: (_) => _load(),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            _buildFilters(context),
            const SizedBox(height: 20),
            SectionHeader(
              title: '${_clientes.length} clientes',
              subtitle: _hasActiveFilters
                  ? 'Resultados con filtros activos'
                  : 'Perfiles reutilizables al tipear DNI en checkout',
            ),
            const SizedBox(height: 12),
            if (_loading && _clientes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_clientes.isEmpty)
              const _EmptyState()
            else
              ..._clientes.map(
                (cliente) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ClienteTile(
                    record: cliente,
                    onTap: () => _openCliente(cliente),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  const _ClienteTile({
    required this.record,
    required this.onTap,
  });

  final CustomerRecord record;
  final VoidCallback onTap;

  String get _initials {
    final parts = record.customer.fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts[1].isNotEmpty) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    final name = record.customer.fullName.trim();
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = record.customer.fullName.trim().isEmpty
        ? 'Sin nombre'
        : record.customer.fullName.trim();
    final dni = record.customer.dni.trim();
    final phone = record.customer.phone.trim();
    final lastSale = record.lastSaleAt;

    return Material(
      color: AppColors.surface,
      borderRadius: AppDecorations.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDecorations.radiusMd,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radiusMd,
            border: Border.all(color: AppColors.border),
            boxShadow: [AppDecorations.softShadow],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                _initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            subtitle: Text(
              [
                if (dni.isNotEmpty) 'DNI $dni',
                if (phone.isNotEmpty) phone,
                if (record.saleCount > 0)
                  '${record.saleCount} compra${record.saleCount == 1 ? '' : 's'}',
                if (lastSale != null)
                  'Última: ${formatDateTime(lastSale.toLocal())}',
              ].join(' · '),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.goldDark),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppDecorations.radiusMd,
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'No hay clientes para mostrar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Se crean al registrar ventas con DNI o al buscar en checkout',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
