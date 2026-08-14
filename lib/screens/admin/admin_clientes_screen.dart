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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!AppConfig.useSupabase) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _repository.list(query: _searchController.text);
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
                labelText: 'Buscar por nombre, DNI, teléfono o mail',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('BUSCAR'),
              ),
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: '${_clientes.length} clientes',
              subtitle: 'Perfiles reutilizables al tipear DNI en checkout',
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
