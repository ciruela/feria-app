import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/admin_user.dart';
import '../models/app_role.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/tenant_session_service.dart';
import '../theme/app_theme.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/admin_pin_entry.dart';
import '../widgets/employee/employee_role_widgets.dart';
import '../widgets/feria_shell.dart';
import '../widgets/supabase_config_banner.dart';
import '../widgets/tenant_app_title.dart';

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
    final exchangeRate = context.watch<ExchangeRateService>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);

    return FeriaScaffold(
      constrainBody: false,
      maxContentWidth: isDesktop ? 1100 : 960,
      appBar: FeriaAppBar(
        title: const TenantAppTitle(),
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
        padding: EdgeInsets.fromLTRB(isDesktop ? 40 : 20, 24, isDesktop ? 40 : 20, 32),
        children: [
          const SupabaseConfigBanner(),
          const RoleGateHero(),
          const SizedBox(height: 28),
          Text('¿Cómo entrás?', style: AppText.heading.copyWith(fontSize: isDesktop ? 32 : 26)),
          const SizedBox(height: 8),
          Text(
            session.isSellerPortalSession
                ? 'Sesión de vendedor: ventas y consulta de precios.'
                : session.isTenantManager
                    ? 'Tu cuenta ya es administración en el servidor. El PIN solo identifica quién opera.'
                    : 'Empleados consultan precios. Administración edita catálogo.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RoleEntryCard(
                    label: AppRole.employee.label,
                    subtitle: 'Consultar precios, stock y carrito',
                    icon: Icons.search_rounded,
                    highlighted: true,
                    onTap: () {
                      context.read<AuthService>().loginAs(AppRole.employee);
                      onEmployee();
                    },
                  ),
                ),
                if (!session.isSellerPortalSession) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: RoleEntryCard(
                      label: AppRole.admin.label,
                      subtitle: session.isTenantManager
                          ? 'Panel completo (rol server: ${session.appRole})'
                          : 'Editar productos, stock y tipo de cambio',
                      icon: Icons.tune_rounded,
                      onTap: () => _askAdminPin(context),
                    ),
                  ),
                ],
              ],
            )
          else ...[
            RoleEntryCard(
              label: AppRole.employee.label,
              subtitle: 'Consultar precios, stock y carrito',
              icon: Icons.search_rounded,
              highlighted: true,
              onTap: () {
                context.read<AuthService>().loginAs(AppRole.employee);
                onEmployee();
              },
            ),
            if (!session.isSellerPortalSession) ...[
              const SizedBox(height: 16),
              RoleEntryCard(
                label: AppRole.admin.label,
                subtitle: session.isTenantManager
                    ? 'Panel completo (rol server: ${session.appRole})'
                    : 'Editar productos, stock y tipo de cambio',
                icon: Icons.tune_rounded,
                onTap: () => _askAdminPin(context),
              ),
            ],
          ],
          if (exchangeRate.hasServerRate) ...[
            const SizedBox(height: 24),
            DollarReferenceChip(
              rate: exchangeRate.rate,
              updatedAt: exchangeRate.updatedAt,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _askAdminPin(BuildContext context) async {
    final session = context.read<TenantSessionService>();
    if (!session.isTenantManager && session.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tu sesión no tiene rol de administración en el servidor.',
          ),
        ),
      );
      return;
    }

    final admin = await showDialog<AdminUser>(
      context: context,
      builder: (_) => const _AdminPinDialog(),
    );

    if (admin == null || !context.mounted) return;
    onAdmin(admin);
  }
}

const _masterId = 'master';

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final _pinKey = GlobalKey<AdminPinEntryState>();
  bool _wrong = false;

  AdminUser? _resolve(String pin) {
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

  void _submit(String pin) {
    final admin = _resolve(pin);
    if (admin != null) {
      Navigator.of(context).pop(admin);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _wrong = true);
    _pinKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        side: const BorderSide(
          color: AppColors.border,
          width: AppDecorations.hairline,
        ),
      ),
      title: const Text('PIN de administración', style: AppText.heading),
      content: AdminPinEntry(
        key: _pinKey,
        wrong: _wrong,
        onChanged: (_) {
          if (_wrong) setState(() => _wrong = false);
        },
        onSubmit: _submit,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
      ],
    );
  }
}

Widget roleBadge(AppRole role) {
  final isAdmin = role == AppRole.admin;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isAdmin ? AppColors.accent : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      border: isAdmin
          ? null
          : Border.all(
              color: AppColors.border,
              width: AppDecorations.hairline,
            ),
    ),
    child: Text(
      role.label.toUpperCase(),
      style: AppText.label.copyWith(
        color: isAdmin ? AppColors.onAccent : AppColors.textMuted,
      ),
    ),
  );
}
