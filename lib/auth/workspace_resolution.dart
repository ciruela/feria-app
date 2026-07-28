import '../services/tenant_session_service.dart';

/// Pantalla raíz que debe mostrar [AuthGate] según sesión Supabase + memberships.
enum AuthShellRoute {
  offlineRoleGate,
  authLanding,
  emailPending,
  bootstrapping,
  noOrganization,
  workspacePicker,
  platformAdmin,
  tenantApp,
  sellerPortal,
}

/// Resuelve la pantalla raíz sin depender del Navigator.
AuthShellRoute resolveAuthShellRoute({
  required bool isConfigured,
  required bool awaitingEmailConfirmation,
  required bool isSignedIn,
  required bool isEmailConfirmed,
  required bool isAnonymous,
  required bool isSellerPortalSession,
  required bool sessionReady,
  required bool bootstrapping,
  required bool provisioning,
  required bool hasNoOrganizationAccess,
  required WorkspaceView view,
  required String? effectiveTenantId,
  required int destinationCount,
}) {
  if (!isConfigured) return AuthShellRoute.offlineRoleGate;
  if (awaitingEmailConfirmation) return AuthShellRoute.emailPending;
  if (isSellerPortalSession) return AuthShellRoute.sellerPortal;
  if (!isSignedIn) return AuthShellRoute.authLanding;
  if (!isEmailConfirmed && !isAnonymous) return AuthShellRoute.emailPending;
  if (!sessionReady || bootstrapping || provisioning) {
    return AuthShellRoute.bootstrapping;
  }
  if (hasNoOrganizationAccess) return AuthShellRoute.noOrganization;

  if (view == WorkspaceView.platform) return AuthShellRoute.platformAdmin;

  if (view == WorkspaceView.tenant &&
      effectiveTenantId != null &&
      effectiveTenantId.isNotEmpty) {
    return AuthShellRoute.tenantApp;
  }

  // Sin tenant activo: siempre selector (aunque haya un solo destino).
  if (destinationCount >= 1) return AuthShellRoute.workspacePicker;

  return AuthShellRoute.noOrganization;
}

/// Decide el workspace activo a partir del JWT y las memberships cargadas.
WorkspaceResolution resolveWorkspace({
  required WorkspaceView currentView,
  required String? jwtTenantId,
  required List<String> membershipIds,
  required bool isPlatformAdmin,
  required bool allowJwtAutoSelect,
}) {
  if (currentView == WorkspaceView.platform) {
    return const WorkspaceResolution(
      view: WorkspaceView.platform,
      tenantId: null,
      autoEnterTenantId: null,
    );
  }

  if (currentView == WorkspaceView.none) {
    if (allowJwtAutoSelect) {
      final jwt = jwtTenantId?.trim();
      if (jwt != null &&
          jwt.isNotEmpty &&
          membershipIds.contains(jwt)) {
        return WorkspaceResolution(
          view: WorkspaceView.tenant,
          tenantId: jwt,
          autoEnterTenantId: null,
          syncActiveTenant: true,
        );
      }
    }

    final destinations =
        membershipIds.length + (isPlatformAdmin ? 1 : 0);

    if (destinations == 1) {
      if (isPlatformAdmin) {
        return const WorkspaceResolution(
          view: WorkspaceView.platform,
          tenantId: null,
          autoEnterTenantId: null,
        );
      }
      if (membershipIds.length == 1) {
        return WorkspaceResolution(
          view: WorkspaceView.none,
          tenantId: null,
          autoEnterTenantId: membershipIds.first,
        );
      }
    }

    return const WorkspaceResolution(
      view: WorkspaceView.none,
      tenantId: null,
      autoEnterTenantId: null,
    );
  }

  final jwt = jwtTenantId?.trim();
  if (jwt != null &&
      jwt.isNotEmpty &&
      membershipIds.contains(jwt)) {
    return WorkspaceResolution(
      view: WorkspaceView.tenant,
      tenantId: jwt,
      autoEnterTenantId: null,
      syncActiveTenant: true,
    );
  }

  final destinations =
      membershipIds.length + (isPlatformAdmin ? 1 : 0);

  if (destinations == 1) {
    if (isPlatformAdmin) {
      return const WorkspaceResolution(
        view: WorkspaceView.platform,
        tenantId: null,
        autoEnterTenantId: null,
      );
    }
    if (membershipIds.length == 1) {
      return WorkspaceResolution(
        view: WorkspaceView.none,
        tenantId: null,
        autoEnterTenantId: membershipIds.first,
      );
    }
  }

  return const WorkspaceResolution(
    view: WorkspaceView.none,
    tenantId: null,
    autoEnterTenantId: null,
  );
}

class WorkspaceResolution {
  const WorkspaceResolution({
    required this.view,
    required this.tenantId,
    required this.autoEnterTenantId,
    this.syncActiveTenant = false,
  });

  final WorkspaceView view;
  final String? tenantId;
  final String? autoEnterTenantId;
  final bool syncActiveTenant;
}
