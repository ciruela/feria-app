import 'package:app_feria/auth/workspace_resolution.dart';
import 'package:app_feria/services/tenant_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveWorkspace', () {
    test('cold start: usa tenant del JWT si hay membership', () {
      final result = resolveWorkspace(
        currentView: WorkspaceView.tenant,
        jwtTenantId: 'tenant-a',
        membershipIds: ['tenant-a', 'tenant-b'],
        isPlatformAdmin: false,
        allowJwtAutoSelect: true,
      );

      expect(result.view, WorkspaceView.tenant);
      expect(result.tenantId, 'tenant-a');
      expect(result.syncActiveTenant, isTrue);
    });

    test('post-login con varias armerías: no auto-aplica JWT', () {
      final result = resolveWorkspace(
        currentView: WorkspaceView.none,
        jwtTenantId: 'tenant-a',
        membershipIds: ['tenant-a', 'tenant-b'],
        isPlatformAdmin: false,
        allowJwtAutoSelect: false,
      );

      expect(result.view, WorkspaceView.none);
      expect(result.autoEnterTenantId, isNull);
    });

    test('cold start con JWT válido entra directo', () {
      final result = resolveWorkspace(
        currentView: WorkspaceView.none,
        jwtTenantId: 'tenant-a',
        membershipIds: ['tenant-a', 'tenant-b'],
        isPlatformAdmin: false,
        allowJwtAutoSelect: true,
      );

      expect(result.view, WorkspaceView.tenant);
      expect(result.tenantId, 'tenant-a');
    });

    test('auto entra con una sola membership', () {
      final result = resolveWorkspace(
        currentView: WorkspaceView.none,
        jwtTenantId: null,
        membershipIds: ['tenant-a'],
        isPlatformAdmin: false,
        allowJwtAutoSelect: true,
      );

      expect(result.autoEnterTenantId, 'tenant-a');
    });

    test('super admin único va a plataforma', () {
      final result = resolveWorkspace(
        currentView: WorkspaceView.none,
        jwtTenantId: null,
        membershipIds: [],
        isPlatformAdmin: true,
        allowJwtAutoSelect: true,
      );

      expect(result.view, WorkspaceView.platform);
    });
  });

  group('resolveAuthShellRoute', () {
    test('tenant activo muestra tenantApp', () {
      expect(
        resolveAuthShellRoute(
          isConfigured: true,
          awaitingEmailConfirmation: false,
          isSignedIn: true,
          isEmailConfirmed: true,
          isAnonymous: false,
          isSellerPortalSession: false,
          sessionReady: true,
          bootstrapping: false,
          provisioning: false,
          hasNoOrganizationAccess: false,
          view: WorkspaceView.tenant,
          effectiveTenantId: 'tenant-a',
          destinationCount: 2,
        ),
        AuthShellRoute.tenantApp,
      );
    });

    test('sesión lista sin tenant muestra picker', () {
      expect(
        resolveAuthShellRoute(
          isConfigured: true,
          awaitingEmailConfirmation: false,
          isSignedIn: true,
          isEmailConfirmed: true,
          isAnonymous: false,
          isSellerPortalSession: false,
          sessionReady: true,
          bootstrapping: false,
          provisioning: false,
          hasNoOrganizationAccess: false,
          view: WorkspaceView.none,
          effectiveTenantId: null,
          destinationCount: 2,
        ),
        AuthShellRoute.workspacePicker,
      );
    });

    test('bootstrap pendiente muestra loader', () {
      expect(
        resolveAuthShellRoute(
          isConfigured: true,
          awaitingEmailConfirmation: false,
          isSignedIn: true,
          isEmailConfirmed: true,
          isAnonymous: false,
          isSellerPortalSession: false,
          sessionReady: false,
          bootstrapping: true,
          provisioning: false,
          hasNoOrganizationAccess: false,
          view: WorkspaceView.none,
          effectiveTenantId: null,
          destinationCount: 2,
        ),
        AuthShellRoute.bootstrapping,
      );
    });

    test('needsPasswordSetup manda a definir contraseña', () {
      expect(
        resolveAuthShellRoute(
          isConfigured: true,
          awaitingEmailConfirmation: false,
          isSignedIn: true,
          isEmailConfirmed: true,
          isAnonymous: false,
          isSellerPortalSession: false,
          sessionReady: true,
          bootstrapping: false,
          provisioning: false,
          hasNoOrganizationAccess: false,
          view: WorkspaceView.tenant,
          effectiveTenantId: 'tenant-a',
          destinationCount: 1,
          needsPasswordSetup: true,
        ),
        AuthShellRoute.setPassword,
      );
    });
  });
}
