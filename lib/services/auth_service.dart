import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_role.dart';
import '../models/audit_entry.dart';
import '../utils/pin_hash.dart';
import '../utils/tenant_cache.dart';
import 'audit_service.dart';
import 'supabase_config_repository.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  static const _pinKeyBase = 'admin_pin';
  static const defaultPin = '2580';

  final SupabaseConfigRepository _configRepo = SupabaseConfigRepository();
  String? _tenantScope;

  String _adminPin = defaultPin;
  String? _cloudPinHash;
  AppRole? _currentRole;

  /// PIN maestro actual (texto plano local / cache). Se muestra en admin para
  /// evitar confusión con el valor por defecto (AR-49).
  String get adminPin => _adminPin;
  bool get isDefaultAdminPin => _adminPin == defaultPin;

  AppRole? get currentRole => _currentRole;
  bool get isAdmin => _currentRole == AppRole.admin;
  bool get isEmployee => _currentRole == AppRole.employee;

  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    if (_tenantScope == next) return;
    _tenantScope = next;
    _adminPin = defaultPin;
    _cloudPinHash = null;
  }

  Future<void> load() async {
    await _loadFromCache();
    if (SupabaseService.isConfigured) {
      try {
        final remote = await _configRepo.fetchAdminMasterPinHash();
        if (remote != null && remote.isNotEmpty) {
          _cloudPinHash = remote;
          // Si el PIN local no coincide con la nube, la nube gana: dejamos de
          // confiar en el cache del device (web vs phone).
          if (!pinMatches(_adminPin, remote)) {
            // No conocemos el plaintext remoto: usamos default solo para display
            // si el hash remoto ES el del default; si no, marcamos custom sin
            // revelar dígitos en este device.
            if (pinMatches(defaultPin, remote)) {
              _adminPin = defaultPin;
            } else {
              // Placeholder: verifyAdminPin usa _cloudPinHash.
              _adminPin = '';
            }
            await _persistCache();
          }
        } else if (!isDefaultAdminPin) {
          // Migración: este device tiene PIN custom y la nube aún no → publicar.
          await _configRepo.upsertAdminMasterPinHash(hashPin(_adminPin));
          _cloudPinHash = hashPin(_adminPin);
        }
      } catch (error) {
        debugPrint('AuthService PIN sync: $error');
      }
    }
    notifyListeners();
  }

  bool verifyAdminPin(String pin) {
    final clean = pin.trim();
    if (clean.isEmpty) return false;
    final cloud = _cloudPinHash;
    if (cloud != null && cloud.isNotEmpty) {
      return pinMatches(clean, cloud);
    }
    return clean == _adminPin;
  }

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

    _adminPin = newPin;
    _cloudPinHash = hashPin(newPin);
    await _persistCache();

    if (SupabaseService.isConfigured) {
      await _configRepo.upsertAdminMasterPinHash(_cloudPinHash!);
    }

    AuditService.instance.log(
      accion: 'Cambió el PIN maestro',
      entidad: AuditEntidad.acceso,
    );
    notifyListeners();
  }

  String get _pinKey => tenantCacheKey(_pinKeyBase, _tenantScope);

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    _adminPin = prefs.getString(_pinKey) ?? defaultPin;
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_adminPin.isEmpty) {
      await prefs.remove(_pinKey);
      return;
    }
    await prefs.setString(_pinKey, _adminPin);
  }
}
