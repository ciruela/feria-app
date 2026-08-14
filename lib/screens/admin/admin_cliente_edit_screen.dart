import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/budget.dart';
import '../../models/budget_customer_controllers.dart';
import '../../models/customer_record.dart';
import '../../models/sale_record.dart';
import '../../services/customer_repository.dart';
import '../../services/sales_metrics_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/uppercase_input.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import 'admin_comprobantes_screen.dart';

class AdminClienteEditScreen extends StatefulWidget {
  const AdminClienteEditScreen({
    super.key,
    required this.clienteId,
    required this.initial,
  });

  final String clienteId;
  final CustomerRecord initial;

  @override
  State<AdminClienteEditScreen> createState() => _AdminClienteEditScreenState();
}

class _AdminClienteEditScreenState extends State<AdminClienteEditScreen> {
  final _repository = CustomerRepository();
  late final BudgetCustomerControllers _controllers;
  List<SaleRecord> _sales = const [];
  bool _loadingSales = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controllers = BudgetCustomerControllers();
    _controllers.applyCustomer(widget.initial.customer);
    _loadSales();
  }

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    if (!AppConfig.useSupabase) return;
    final dni = widget.initial.customer.dni.trim();
    if (dni.isEmpty) return;

    setState(() => _loadingSales = true);
    try {
      final sales = await SalesMetricsService().salesByDni(dni);
      if (!mounted) return;
      setState(() {
        _sales = sales;
        _loadingSales = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSales = false);
    }
  }

  BudgetCustomer get _customer => BudgetCustomer(
        fullName: _controllers.fullName.text.trim(),
        dni: widget.initial.customer.dni,
        clu: _controllers.clu.text.trim(),
        cluExpiry: _controllers.cluExpiry.text.trim(),
        phone: _controllers.phone.text.trim(),
        email: _controllers.email.text.trim(),
        fiscalCondition: _controllers.fiscalCondition.text.trim(),
        address: _controllers.address.text.trim(),
        city: _controllers.city.text.trim(),
        notes: _controllers.notes.text.trim(),
      );

  Future<void> _save() async {
    if (_saving) return;
    if (_customer.fullName.trim().length < 3) {
      setState(() => _error = 'El nombre debe tener al menos 3 caracteres.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (AppConfig.useSupabase) {
        await context.read<TenantSessionService>().ensureSupabaseWriteContext();
      }
      final ok = await _repository.update(widget.clienteId, _customer);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _error = 'No se pudo actualizar el cliente.';
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente actualizado')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  void _openSale(SaleRecord sale) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminComprobanteDetailScreen(
          sale: sale,
          onVoid: _loadSales,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastSale = widget.initial.lastSaleAt;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: Text(
          widget.initial.customer.fullName.trim().isEmpty
              ? 'Cliente'
              : widget.initial.customer.fullName.trim(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('GUARDAR'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          StatCard(
            icon: Icons.receipt_long_rounded,
            label: 'Historial de compras',
            value: '${widget.initial.saleCount} venta${widget.initial.saleCount == 1 ? '' : 's'}',
            subtitle: lastSale == null
                ? 'Sin compras registradas'
                : 'Última: ${formatDateTime(lastSale.toLocal())}',
            accentColor: AppColors.accent,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Datos del cliente',
            subtitle: 'El DNI no se modifica — es la clave del perfil',
          ),
          const SizedBox(height: 12),
          _field('DNI / CUIT', _controllers.dni, readOnly: true),
          _field('Nombre completo', _controllers.fullName),
          _field('CLU', _controllers.clu),
          _field('Vto CLU', _controllers.cluExpiry),
          _field('Teléfono', _controllers.phone),
          _field('Mail', _controllers.email),
          _field('Condición fiscal', _controllers.fiscalCondition),
          _field('Domicilio', _controllers.address),
          _field('Localidad', _controllers.city),
          _field('Observaciones', _controllers.notes, maxLines: 3),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Comprobantes',
            subtitle: 'Ventas asociadas a este DNI',
          ),
          const SizedBox(height: 12),
          if (_loadingSales)
            const Center(child: CircularProgressIndicator())
          else if (_sales.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppDecorations.radiusMd,
              ),
              child: const Text(
                'No hay comprobantes para este DNI.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ..._sales.map(
              (sale) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SaleTile(sale: sale, onTap: () => _openSale(sale)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        textCapitalization: readOnly
            ? TextCapitalization.none
            : TextCapitalization.characters,
        inputFormatters:
            readOnly ? null : UpperCaseTextFormatter.formatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: readOnly ? AppColors.surfaceMuted : AppColors.surface,
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.sale,
    required this.onTap,
  });

  final SaleRecord sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = sale.collectedUsd > 0 && sale.collectedArs <= 0
        ? formatUsd(sale.collectedUsd)
        : formatArs(sale.collectedArs);

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
          ),
          child: ListTile(
            title: Text(
              formatDateTime(sale.createdAt.toLocal()),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                total,
                if (sale.anulada) 'Anulada',
                if (sale.facturada) 'Facturada',
              ].join(' · '),
              style: TextStyle(
                color: sale.anulada ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      ),
    );
  }
}
