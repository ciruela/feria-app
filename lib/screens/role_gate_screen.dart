import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_user.dart';
import '../models/app_role.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/tenant_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/big_action_button.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';
import '../widgets/supabase_config_banner.dart';

typedef AdminEntryCallback = void Function(AdminUser admin);

/// Selector empleado / administración. Navegación vía callbacks (declarativa).
class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({
    super.key,
    required this.onEmployee,
    required this.onAdmin,
  });

  final VoidCallback onEmployee;
  final AdminEntryCallback onAdmin;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Catálogo Feria'),
        showBackButton: false,
        leading: session.isSignedIn && session.destinationCount > 1
            ? IconButton(
                tooltip: 'Elegir otra armería',
                onPressed: () =>
                    context.read<TenantSessionService>().backToSelector(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        actions: [
          if (session.isSignedIn && session.destinationCount > 1)
            IconButton(
              tooltip: 'Cambiar de armería',
              onPressed: () =>
                  context.read<TenantSessionService>().backToSelector(),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          if (session.isSignedIn)
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => context.read<TenantSessionService>().signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          const SupabaseConfigBanner(),
          _HeroHeader(),
          const SizedBox(height: 28),
          const SectionHeader(
            title: '¿Cómo entrás?',
            subtitle: 'Empleados consultan precios. Administración edita catálogo.',
          ),
          const SizedBox(height: 22),
          BigActionButton(
            label: AppRole.employee.label,
            subtitle: 'Consultar precios, stock y carrito',
            icon: Icons.storefront_rounded,
            accentColor: AppColors.accent,
            onTap: () {
              context.read<AuthService>().loginAs(AppRole.employee);
              onEmployee();
            },
          ),
          const SizedBox(height: 16),
          BigActionButton(
            label: AppRole.admin.label,
            subtitle: 'Editar productos, stock y tipo de cambio',
            icon: Icons.admin_panel_settings_rounded,
            accentColor: AppColors.goldDark,
            onTap: () => _askAdminPin(context),
          ),
        ],
      ),
    );
  }

  Future<void> _askAdminPin(BuildContext context) async {
    final admin = await showDialog<AdminUser>(
      context: context,
      builder: (_) => const _AdminPinDialog(),
    );

    if (admin == null || !context.mounted) return;
    onAdmin(admin);
  }
}

const _masterId = 'master';

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppDecorations.cardGradient,
        borderRadius: AppDecorations.radiusLg,
        boxShadow: [AppDecorations.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppDecorations.goldGradient,
              borderRadius: AppDecorations.radiusMd,
            ),
            child: const Icon(
              Icons.local_mall_rounded,
              color: AppColors.primaryDark,
              size: 38,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FERIA ARMAS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Caza · Pesca · Munición',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
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

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AdminUser? _resolve() {
    final pin = _controller.text.trim();
    final named = context.read<AdminService>().verifyPin(pin);
    if (named != null) return named;
    if (context.read<AuthService>().verifyAdminPin(pin)) {
      return const AdminUser(
        id: _masterId,
        nombre: 'Admin',
        pin: '',
      );
    }
    return null;
  }

  void _submit() {
    final admin = _resolve();
    if (admin != null) {
      Navigator.of(context).pop(admin);
    } else {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: AppColors.goldDark, size: 28),
      ),
      title: const Text('PIN de administración'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(
            labelText: 'Ingresá el PIN',
            hintText: '••••',
          ),
          validator: (value) {
            if (_resolve() == null) {
              return 'PIN incorrecto';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldDark,
          ),
          child: const Text('ENTRAR'),
        ),
      ],
    );
  }
}

Widget roleBadge(AppRole role) {
  final isAdmin = role == AppRole.admin;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      gradient: isAdmin ? AppDecorations.goldGradient : null,
      color: isAdmin ? null : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isAdmin
            ? AppColors.goldDark.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.25),
      ),
    ),
    child: Text(
      role.label.toUpperCase(),
      style: TextStyle(
        color: isAdmin ? AppColors.primaryDark : Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}
