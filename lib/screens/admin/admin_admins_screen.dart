import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/admin_user.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/uppercase_input.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

class AdminAdminsScreen extends StatefulWidget {
  const AdminAdminsScreen({super.key});

  @override
  State<AdminAdminsScreen> createState() => _AdminAdminsScreenState();
}

class _AdminAdminsScreenState extends State<AdminAdminsScreen> {
  Future<void> _refresh() async {
    await context.read<AdminService>().syncFromCloud();
  }

  Future<void> _addAdmin() async {
    final result = await _promptAdmin(title: 'Agregar administrador');
    if (result == null || !mounted) return;

    try {
      await context.read<AdminService>().addAdmin(
            nombre: result.nombre,
            pin: result.pin,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.nombre} agregado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _editAdmin(AdminUser admin) async {
    final result = await _promptAdmin(
      title: 'Editar administrador',
      initialName: admin.nombre,
      pinOptional: true,
    );
    if (result == null || !mounted) return;

    try {
      await context.read<AdminService>().updateAdmin(
            admin.id,
            nombre: result.nombre,
            pin: result.pin.isEmpty ? null : result.pin,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador actualizado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _toggleActive(AdminUser admin) async {
    try {
      await context
          .read<AdminService>()
          .updateAdmin(admin.id, activo: !admin.activo);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _confirmDelete(AdminUser admin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar administrador'),
        content: Text(
          '¿Eliminar a ${admin.nombre}? '
          'No podrá volver a entrar con su PIN. El registro de actividad se mantiene.',
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
      await context.read<AdminService>().deleteAdmin(admin.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${admin.nombre} eliminado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $error')),
      );
    }
  }

  Future<_AdminForm?> _promptAdmin({
    required String title,
    String initialName = '',
    bool pinOptional = false,
  }) async {
    final nameController = TextEditingController(text: initialName);
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<_AdminForm>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: UpperCaseTextFormatter.formatters,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: JUAN PÉREZ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().length < 2)
                    ? 'Nombre muy corto'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: pinOptional ? 'Nuevo PIN (opcional)' : 'PIN',
                  hintText: '4 a 8 dígitos',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (pinOptional && v.isEmpty) return null;
                  if (v.length < 4) return 'Mínimo 4 dígitos';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  context,
                  _AdminForm(
                    nombre: nameController.text.trim(),
                    pin: pinController.text.trim(),
                  ),
                );
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AdminService>();
    final admins = service.admins;
    final current = service.current;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Administradores'),
        actions: [
          if (AppConfig.useSupabase)
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAdmin,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('AGREGAR'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            if (!AppConfig.useSupabase)
              const _Banner(
                icon: Icons.info_outline,
                color: AppColors.goldDark,
                message:
                    'Sin Supabase los administradores quedan solo en este dispositivo.',
              ),
            if (service.lastError != null) ...[
              _Banner(
                icon: Icons.error_outline,
                color: AppColors.danger,
                message: service.lastError!,
              ),
              const SizedBox(height: 16),
            ],
            const _Banner(
              icon: Icons.vpn_key_rounded,
              color: AppColors.goldDark,
              message:
                  'Estos PIN identifican quién opera en el panel y en la auditoría. '
                  'Para dar acceso con email a la armería, usá Equipo de la armería.',
            ),
            const SizedBox(height: 16),
            if (current != null)
              StatCard(
                icon: Icons.badge_rounded,
                label: 'Sesión actual',
                value: current.nombre,
                subtitle: 'Sus acciones quedan registradas',
                accentColor: AppColors.goldDark,
              ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Administradores',
              subtitle: 'Cada uno entra con su propio PIN',
            ),
            const SizedBox(height: 12),
            if (admins.isEmpty)
              const _EmptyState()
            else
              ...admins.map(
                (admin) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AdminTile(
                    admin: admin,
                    isCurrent: current?.id == admin.id,
                    onEdit: () => _editAdmin(admin),
                    onToggle: () => _toggleActive(admin),
                    onDelete: () => _confirmDelete(admin),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminForm {
  const _AdminForm({required this.nombre, required this.pin});
  final String nombre;
  final String pin;
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.admin,
    required this.isCurrent,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminUser admin;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final inactive = !admin.activo;

    return Opacity(
      opacity: inactive ? 0.65 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusMd,
          border: Border.all(
            color: inactive
                ? AppColors.border
                : AppColors.goldDark.withValues(alpha: 0.35),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: inactive
                ? AppColors.surfaceMuted
                : AppColors.gold.withValues(alpha: 0.18),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.goldDark),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  admin.nombre,
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'VOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            inactive ? 'Inactivo · PIN ••••' : 'Activo · PIN ••••',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Opciones',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'toggle':
                  onToggle();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar nombre / PIN'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(inactive
                      ? Icons.person_add_alt_1_outlined
                      : Icons.person_off_outlined),
                  title: Text(inactive ? 'Reactivar' : 'Desactivar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.danger),
                  title: Text('Eliminar',
                      style: TextStyle(color: AppColors.danger)),
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
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
          Icon(Icons.admin_panel_settings_outlined,
              size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            'No hay administradores con nombre',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Agregá el primero para registrar quién hace cada acción',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
