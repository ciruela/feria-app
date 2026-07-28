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
  GlobalKey<NavigatorState>? _stackKey;

  TenantAppPhase _phase = TenantAppPhase.roleGate;

  TenantAppPhase get phase => _phase;

  GlobalKey<NavigatorState> navigatorKeyFor(TenantAppPhase phase) {
    if (phase == TenantAppPhase.employeeHome ||
        phase == TenantAppPhase.adminHome) {
      _stackKey ??= GlobalKey<NavigatorState>();
      return _stackKey!;
    }
    return GlobalKey<NavigatorState>();
  }

  void reset() {
    _phase = TenantAppPhase.roleGate;
    _stackKey = null;
    notifyListeners();
  }

  void openSellerSelect() {
    _phase = TenantAppPhase.sellerSelect;
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
    _stackKey?.currentState?.popUntil((route) => route.isFirst);
  }
}
