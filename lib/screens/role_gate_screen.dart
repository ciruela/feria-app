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
import '../widgets/employee/role_gate_desktop.dart';
import '../widgets/employee/role_gate_mobile.dart';
import '../widgets/supabase_config_banner.dart';

typedef AdminEntryCallback = void Function(AdminUser admin);

/// Selector empleado / administración. Marca Armenext — igual en todas las armerías.
class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({
    super.key,
    required this.onEmployee,
    required this.onAdmin,
  });

  final VoidCallback onEmployee;
  final AdminEntryCallback onAdmin;

  String _subtitle(TenantSessionService session, {required bool isDesktop}) {
    if (session.isSellerPortalSession) {
      return 'Sesión de vendedor: ventas y consulta de precios.';
    }
    if (!isDesktop && session.isTenantManager) {
      return 'Tu cuenta ya es administración en el servidor. El PIN solo identifica quién opera.';
    }
    return 'Empleados consultan precios. Administración edita catálogo.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final exchangeRate = context.watch<ExchangeRateService>();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);

    if (isDesktop) {
      return RoleGateDesktopLayout(
        subtitle: _subtitle(session, isDesktop: true),
        showAdminCard: !session.isSellerPortalSession,
        onEmployee: () {
          context.read<AuthService>().loginAs(AppRole.employee);
          onEmployee();
        },
        onAdmin: () => _askAdminPin(context),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          RoleGateMobileLayout(
            subtitle: _subtitle(session, isDesktop: false),
            showAdminCard: !session.isSellerPortalSession,
            exchangeRate:
                exchangeRate.hasServerRate ? exchangeRate.rate : null,
            exchangeUpdatedAt: exchangeRate.updatedAt,
            header: const SupabaseConfigBanner(),
            onEmployee: () {
              context.read<AuthService>().loginAs(AppRole.employee);
              onEmployee();
            },
            onAdmin: () => _askAdminPin(context),
          ),
          if (session.isSignedIn)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: _MobileSessionActions(session: session),
            ),
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

class _MobileSessionActions extends StatelessWidget {
  const _MobileSessionActions({required this.session});

  final TenantSessionService session;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.destinationCount > 1)
          IconButton(
            tooltip: 'Cambiar de armería',
            onPressed: () =>
                context.read<TenantSessionService>().backToSelector(),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: () => context.read<TenantSessionService>().signOut(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
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
        // AR-36: no robar el foco del teclado del PIN.
        ExcludeFocus(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
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
