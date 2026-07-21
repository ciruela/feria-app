import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_role.dart';

class AuthService extends ChangeNotifier {
  static const _pinKey = 'admin_pin';
  static const defaultPin = '2580';

  String _adminPin = defaultPin;
  AppRole? _currentRole;

  AppRole? get currentRole => _currentRole;
  bool get isAdmin => _currentRole == AppRole.admin;
  bool get isEmployee => _currentRole == AppRole.employee;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _adminPin = prefs.getString(_pinKey) ?? defaultPin;
    notifyListeners();
  }

  bool verifyAdminPin(String pin) => pin == _adminPin;

  void loginAs(AppRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    notifyListeners();
  }

  Future<void> changeAdminPin(String newPin) async {
    if (newPin.length < 4) return;

    final prefs = await SharedPreferences.getInstance();
    _adminPin = newPin;
    await prefs.setString(_pinKey, newPin);
    notifyListeners();
  }
}
