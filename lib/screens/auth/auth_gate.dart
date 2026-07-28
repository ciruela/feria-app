import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/workspace_resolution.dart';
import '../../services/in_tenant_flow_service.dart';
import '../../services/tenant_session_service.dart';
import '../employee/employee_home_screen.dart';
import '../super_admin/super_admin_home_screen.dart';
import 'auth_landing_screen.dart';
import 'email_confirmation_screen.dart';
import 'no_organization_screen.dart';
import 'seller_portal_scope_loader.dart';
import 'tenant_app_shell.dart';
import 'tenant_scope_loader.dart';
import 'workspace_selector_screen.dart';

/// Raíz de la app: una sola fuente de verdad para auth + workspace + tenant.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSessionReady());
  }

  void _ensureSessionReady() {
    if (!mounted) return;
    context.read<TenantSessionService>().ensureSessionReady();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();

    if (!session.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<InTenantFlowService>().reset();
      });
    } else if (session.needsSessionBootstrap) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSessionReady());
    }

    final route = resolveAuthShellRoute(
      isConfigured: session.isConfigured,
      awaitingEmailConfirmation: session.awaitingEmailConfirmation,
      isSignedIn: session.isSignedIn,
      isEmailConfirmed: session.isEmailConfirmed,
      isAnonymous: session.isAnonymous,
      isSellerPortalSession: session.isSellerPortalSession,
      sessionReady: session.sessionReady,
      bootstrapping: session.bootstrapping,
      provisioning: session.provisioning,
      hasNoOrganizationAccess: session.hasNoOrganizationAccess,
      view: session.view,
      effectiveTenantId: session.effectiveTenantId,
      destinationCount: session.destinationCount,
    );

    return switch (route) {
      AuthShellRoute.offlineRoleGate => const TenantAppShell(),
      AuthShellRoute.authLanding => const AuthLandingScreen(),
      AuthShellRoute.emailPending => const EmailConfirmationScreen(),
      AuthShellRoute.bootstrapping => const _BootLoading(),
      AuthShellRoute.noOrganization => const NoOrganizationScreen(),
      AuthShellRoute.workspacePicker => const WorkspaceSelectorScreen(),
      AuthShellRoute.platformAdmin => const SuperAdminHomeScreen(),
      AuthShellRoute.sellerPortal => SellerPortalScopeLoader(
          key: ValueKey(session.effectiveTenantId ?? 'seller'),
          child: const EmployeeHomeScreen(),
        ),
      AuthShellRoute.tenantApp => TenantScopeLoader(
          key: ValueKey(session.effectiveTenantId ?? 'tenant'),
          child: const TenantAppShell(),
        ),
    };
  }
}

class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
