import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_user.dart';
import '../../models/app_role.dart';
import '../../models/audit_entry.dart';
import '../../services/admin_service.dart';
import '../../services/audit_service.dart';
import '../../services/auth_service.dart';
import '../../services/in_tenant_flow_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../admin/admin_home_screen.dart';
import '../employee/employee_catalog_screen.dart';
import '../role_gate_screen.dart';
import '../seller_select_screen.dart';

/// Shell declarativo del tenant: role gate → vendedor → empleado/admin.
/// Un [Navigator] anidado solo para catálogo, carrito y pantallas hijas.
class TenantAppShell extends StatelessWidget {
  const TenantAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<InTenantFlowService>().phase;
    final flow = context.read<InTenantFlowService>();

    switch (phase) {
      case TenantAppPhase.roleGate:
        return RoleGateScreen(
          onEmployee: flow.openSellerSelect,
          onAdmin: (admin) => _startAdminSession(context, admin, flow),
        );
      case TenantAppPhase.sellerSelect:
        return SellerSelectScreen(
          onSellerSelected: (_) => flow.openEmployeeHome(),
        );
      case TenantAppPhase.employeeHome:
        return Navigator(
          key: flow.employeeNavigatorKey(),
          onGenerateInitialRoutes: (_, __) {
            return [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/'),
                builder: (_) => const EmployeeCatalogScreen(),
              ),
            ];
          },
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const EmployeeCatalogScreen(),
            );
          },
        );
      case TenantAppPhase.adminHome:
        return Navigator(
          key: flow.adminNavigatorKey(),
          onGenerateInitialRoutes: (_, __) {
            return [
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/'),
                builder: (_) => const AdminHomeScreen(),
              ),
            ];
          },
          onGenerateRoute: (settings) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const AdminHomeScreen(),
            );
          },
        );
    }
  }

  void _startAdminSession(
    BuildContext context,
    AdminUser admin,
    InTenantFlowService flow,
  ) {
    context.read<AuthService>().loginAs(AppRole.admin);
    context.read<AdminService>().startSession(admin);
    final email = context.read<TenantSessionService>().email.trim();
    final auditName =
        admin.id == 'master' && email.isNotEmpty ? email : admin.nombre;
    AuditService.instance.setActor(
      id: admin.id == 'master' ? null : admin.id,
      nombre: auditName,
    );
    AuditService.instance.log(
      accion: 'Ingresó al panel de administración',
      entidad: AuditEntidad.acceso,
    );
    flow.openAdminHome();
  }
}

/// Sale del modo empleado/admin y vuelve al selector de rol.
void exitInTenantFlow(BuildContext context) {
  final auth = context.read<AuthService>();
  if (auth.isAdmin) {
    AuditService.instance.log(
      accion: 'Salió del panel de administración',
      entidad: AuditEntidad.acceso,
    );
    AuditService.instance.clearActor();
    context.read<AdminService>().endSession();
  }
  auth.logout();
  context.read<SellerService>().clearSelection();
  context.read<InTenantFlowService>().reset();
}

/// Desde catálogo/carrito, vuelve al inicio del vendedor (navigator anidado).
void goToEmployeeHome(BuildContext context) {
  context.read<InTenantFlowService>().popToEmployeeHome();
}
