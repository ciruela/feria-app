import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/seller.dart';
import '../../services/seller_portal_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../../utils/uppercase_input.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

class AdminSellersScreen extends StatefulWidget {
  const AdminSellersScreen({super.key});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  bool _showInactive = true;

  Future<void> _refresh() async {
    await context.read<SellerService>().syncFromCloud();
  }

  Future<String?> _promptSellerName({
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: UpperCaseTextFormatter.formatters,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            hintText: 'Ej: JUAN PÉREZ',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _addSeller() async {
    final name = await _promptSellerName(
      title: 'Agregar vendedor',
      confirmLabel: 'AGREGAR',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    try {
      await context.read<SellerService>().addSeller(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${name.trim()} agregado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _editSeller(Seller seller) async {
    final name = await _promptSellerName(
      title: 'Editar vendedor',
      confirmLabel: 'GUARDAR',
      initialValue: seller.nombre,
    );

    if (name == null || name.trim().isEmpty || !mounted) return;
    if (name.trim().toLowerCase() == seller.nombre.toLowerCase()) return;

    try {
      await context.read<SellerService>().updateSellerName(seller.id, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nombre actualizado a ${name.trim()}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _confirmDelete(Seller seller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar vendedor'),
        content: Text(
          '¿Eliminar a ${seller.nombre}? '
          'Desaparece del listado. Las ventas ya registradas se mantienen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await context.read<SellerService>().deleteSeller(seller.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${seller.nombre} eliminado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $error')),
      );
    }
  }

  Future<void> _confirmDeactivate(Seller seller) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar vendedor'),
        content: Text(
          '¿Desactivar a ${seller.nombre}? '
          'No va a aparecer al elegir vendedor, pero se mantienen sus ventas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DESACTIVAR'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    await context.read<SellerService>().deactivateSeller(seller.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${seller.nombre} desactivado')),
    );
  }

  Future<void> _reactivate(Seller seller) async {
    await context.read<SellerService>().reactivateSeller(seller.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${seller.nombre} reactivado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SellerService>();
    final sellers = service.allSellers.where((seller) {
      return _showInactive || seller.activo;
    }).toList();

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Vendedores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: service.isSyncing ? null : _refresh,
            icon: service.isSyncing
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSeller,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('AGREGAR'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            if (!AppConfig.useSupabase)
              const _InfoBanner(
                message:
                    'Sin Supabase los cambios quedan solo en este dispositivo.',
              ),
            if (service.lastError != null) ...[
              _ErrorBanner(message: service.lastError!),
              const SizedBox(height: 16),
            ],
            if (AppConfig.useSupabase) const _SellerPortalAccessCard(),
            if (AppConfig.useSupabase) const SizedBox(height: 20),
            StatCard(
              icon: Icons.groups_rounded,
              label: 'Equipo de ventas',
              value: '${service.activeCount} activos',
              subtitle: service.inactiveCount > 0
                  ? '${service.inactiveCount} inactivos'
                  : AppConfig.useSupabase
                      ? 'Sincronizado en tiempo real'
                      : null,
              accentColor: AppColors.armaCorta,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Lista del equipo',
                    subtitle: 'Aparecen al entrar como vendedor',
                  ),
                ),
                FilterChip(
                  label: const Text('Ver inactivos'),
                  selected: _showInactive,
                  onSelected: (value) => setState(() => _showInactive = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sellers.isEmpty)
              const _EmptyState()
            else
              ...sellers.map(
                (seller) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SellerAdminTile(
                    seller: seller,
                    onEdit: () => _editSeller(seller),
                    onDeactivate: () => _confirmDeactivate(seller),
                    onDelete: () => _confirmDelete(seller),
                    onReactivate: () => _reactivate(seller),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SellerAdminTile extends StatelessWidget {
  const _SellerAdminTile({
    required this.seller,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
    required this.onReactivate,
  });

  final Seller seller;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;

  String get _initials {
    final parts = seller.nombre.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return seller.nombre.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final inactive = !seller.activo;

    return Opacity(
      opacity: inactive ? 0.65 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusMd,
          border: Border.all(
            color: inactive ? AppColors.border : AppColors.armaCorta.withValues(alpha: 0.35),
          ),
          boxShadow: inactive ? null : [AppDecorations.softShadow],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: inactive
                ? AppColors.surfaceMuted
                : AppColors.armaCorta.withValues(alpha: 0.15),
            child: Text(
              _initials,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: inactive ? AppColors.textSecondary : AppColors.armaCorta,
              ),
            ),
          ),
          title: Text(
            seller.nombre,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          subtitle: Text(
            inactive ? 'Inactivo · ${seller.id}' : 'Activo · ${seller.id}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'deactivate':
                  onDeactivate();
                case 'reactivate':
                  onReactivate();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar nombre'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (inactive)
                const PopupMenuItem(
                  value: 'reactivate',
                  child: ListTile(
                    leading: Icon(Icons.person_add_alt_1_outlined),
                    title: Text('Reactivar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading: Icon(Icons.person_off_outlined),
                    title: Text('Desactivar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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

class _SellerPortalAccessCard extends StatefulWidget {
  const _SellerPortalAccessCard();

  @override
  State<_SellerPortalAccessCard> createState() =>
      _SellerPortalAccessCardState();
}

class _SellerPortalAccessCardState extends State<_SellerPortalAccessCard> {
  final _portal = SellerPortalService();
  final _codeController = TextEditingController();
  String? _slug;
  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadSlug();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSlug() async {
    try {
      final slug = await _portal.fetchCurrentTenantSlug();
      if (!mounted) return;
      setState(() {
        _slug = slug;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveCode() async {
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _message = 'Usá al menos 4 caracteres');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      await _portal.setPortalCode(code);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Código actualizado. Compartilo con tu equipo de ventas.';
        _codeController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                'Acceso de vendedores (sin registro)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _loading
                ? 'Cargando dominio…'
                : _slug == null
                    ? 'Dominio: —'
                    : 'URL: ${tenantPortalUrl(_slug!)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'En la pantalla de inicio tus vendedores eligen '
            '“Entrar como vendedor”, ponen este dominio y la clave que definas acá.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Nueva clave de vendedores',
              hintText: 'Mínimo 4 caracteres',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _saving ? null : _saveCode,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('GUARDAR CLAVE'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                fontSize: 13,
                color: _message!.startsWith('Código')
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ],
        ],
      ),
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
            'No hay vendedores para mostrar',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Agregá el primero con el botón de abajo',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
