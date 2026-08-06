import 'package:flutter/material.dart';

/// Fase dentro de una armería ya seleccionada (sin Navigator en la raíz).
enum TenantAppPhase {
  roleGate,
  sellerSelect,
  employeeHome,
  adminHome,
}

/// Coordina empleado/admin dentro del tenant. Cambios de fase = rebuild declarativo.
class InTenantFlowService extends ChangeNotifier {
  GlobalKey<NavigatorState>? _employeeStackKey;
  GlobalKey<NavigatorState>? _adminStackKey;

  TenantAppPhase _phase = TenantAppPhase.roleGate;

  TenantAppPhase get phase => _phase;

  GlobalKey<NavigatorState> employeeNavigatorKey() {
    _employeeStackKey ??= GlobalKey<NavigatorState>();
    return _employeeStackKey!;
  }

  GlobalKey<NavigatorState> adminNavigatorKey() {
    _adminStackKey ??= GlobalKey<NavigatorState>();
    return _adminStackKey!;
  }

  void reset() {
    _phase = TenantAppPhase.roleGate;
    _employeeStackKey = null;
    _adminStackKey = null;
    notifyListeners();
  }

  void openSellerSelect() {
    _phase = TenantAppPhase.sellerSelect;
    notifyListeners();
  }

  void backToRoleGate() {
    _phase = TenantAppPhase.roleGate;
    notifyListeners();
  }

  void openEmployeeHome() {
    _phase = TenantAppPhase.employeeHome;
    notifyListeners();
  }

  void openAdminHome() {
    _phase = TenantAppPhase.adminHome;
    notifyListeners();
  }

  void popToEmployeeHome() {
    _employeeStackKey?.currentState?.popUntil((route) => route.isFirst);
  }
}
