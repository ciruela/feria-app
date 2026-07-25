import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/admin_user.dart';
import 'supabase_admin_repository.dart';
import 'supabase_service.dart';

class AdminService extends ChangeNotifier {
  static const _cacheKey = 'admins_cache_json';

  List<AdminUser> _admins = [];
  AdminUser? _current;
  String? _lastError;
  RealtimeChannel? _realtimeChannel;

  final SupabaseAdminRepository _repo = SupabaseAdminRepository();

  List<AdminUser> get admins {
    final list = List<AdminUser>.from(_admins);
    list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return list;
  }

  List<AdminUser> get activeAdmins =>
      admins.where((admin) => admin.activo).toList();

  int get activeCount => activeAdmins.length;

  AdminUser? get current => _current;
  String? get lastError => _lastError;

  Future<void> load() async {
    await _loadFromCache();
    if (AppConfig.useSupabase) {
      await syncFromCloud(silent: _admins.isNotEmpty);
      _subscribeRealtime();
    }
  }

  Future<void> syncFromCloud({bool silent = false}) async {
    if (!AppConfig.useSupabase) return;
    try {
      final remote = await _repo.fetchAll();
      _admins = remote;
      await _persistCache();
      if (!silent) _lastError = null;
      notifyListeners();
    } catch (error) {
      if (silent) {
        debugPrint('AdminService silent sync: $error');
      } else {
        _lastError = error.toString();
        notifyListeners();
      }
    }
  }

  /// Devuelve el admin activo cuyo PIN coincide, o null.
  AdminUser? verifyPin(String pin) {
    final clean = pin.trim();
    if (clean.isEmpty) return null;
    for (final admin in _admins) {
      if (admin.activo && admin.pin == clean) return admin;
    }
    return null;
  }

  bool pinInUse(String pin, {String? exceptId}) {
    final clean = pin.trim();
    return _admins.any(
      (admin) => admin.id != exceptId && admin.pin == clean,
    );
  }

  void startSession(AdminUser admin) {
    _current = admin;
    notifyListeners();
  }

  void endSession() {
    _current = null;
    notifyListeners();
  }

  Future<AdminUser> addAdmin({
    required String nombre,
    required String pin,
  }) async {
    final trimmedNombre = nombre.trim().toUpperCase();
    final trimmedPin = pin.trim();

    if (trimmedNombre.length < 2) {
      throw ArgumentError('El nombre debe tener al menos 2 caracteres');
    }
    if (trimmedPin.length < 4) {
      throw ArgumentError('El PIN debe tener al menos 4 dígitos');
    }
    if (_admins.any(
      (a) => a.nombre.toLowerCase() == trimmedNombre.toLowerCase(),
    )) {
      throw ArgumentError('Ya existe un administrador con ese nombre');
    }
    if (pinInUse(trimmedPin)) {
      throw ArgumentError('Ese PIN ya está en uso');
    }

    final admin = AdminUser(
      id: _nextId(),
      nombre: trimmedNombre,
      pin: trimmedPin,
      activo: true,
    );

    _admins.add(admin);
    await _persistCache();
    await _push(admin);
    notifyListeners();
    return admin;
  }

  Future<void> updateAdmin(
    String id, {
    String? nombre,
    String? pin,
    bool? activo,
  }) async {
    final index = _admins.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final current = _admins[index];

    var newNombre = current.nombre;
    if (nombre != null) {
      newNombre = nombre.trim().toUpperCase();
      if (newNombre.length < 2) {
        throw ArgumentError('El nombre debe tener al menos 2 caracteres');
      }
      if (_admins.any(
        (a) => a.id != id && a.nombre.toLowerCase() == newNombre.toLowerCase(),
      )) {
        throw ArgumentError('Ya existe un administrador con ese nombre');
      }
    }

    var newPin = current.pin;
    if (pin != null && pin.trim().isNotEmpty) {
      newPin = pin.trim();
      if (newPin.length < 4) {
        throw ArgumentError('El PIN debe tener al menos 4 dígitos');
      }
      if (pinInUse(newPin, exceptId: id)) {
        throw ArgumentError('Ese PIN ya está en uso');
      }
    }

    final updated = current.copyWith(
      nombre: newNombre,
      pin: newPin,
      activo: activo ?? current.activo,
    );
    _admins[index] = updated;
    if (_current?.id == id) _current = updated;

    await _persistCache();
    await _push(updated);
    notifyListeners();
  }

  Future<void> deleteAdmin(String id) async {
    _admins.removeWhere((a) => a.id == id);
    if (_current?.id == id) _current = null;

    await _persistCache();
    if (SupabaseService.isConfigured) {
      try {
        await _repo.delete(id);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }
    notifyListeners();
  }

  String _nextId() {
    var max = 0;
    for (final admin in _admins) {
      if (admin.id.startsWith('a')) {
        final number = int.tryParse(admin.id.substring(1));
        if (number != null && number > max) max = number;
      }
    }
    return 'a${max + 1}';
  }

  Future<void> _push(AdminUser admin) async {
    if (!SupabaseService.isConfigured) return;
    try {
      await _repo.upsert(admin);
    } catch (error) {
      _lastError = error.toString();
    }
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return;
    try {
      final data = json.decode(cached) as Map<String, dynamic>;
      final list = data['admins'] as List<dynamic>? ?? [];
      _admins = list
          .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _admins = [];
    }
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode({'admins': _admins.map((a) => a.toJson()).toList()}),
    );
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('public:administradores')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'administradores',
          callback: (payload) {
            try {
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                case PostgresChangeEvent.update:
                  final record = payload.newRecord;
                  if (record.isEmpty) return;
                  _applyRemote(_repo.adminFromRow(record));
                case PostgresChangeEvent.delete:
                  final id = payload.oldRecord['id'] as String?;
                  if (id != null) _removeRemote(id);
                default:
                  break;
              }
            } catch (error) {
              debugPrint('AdminService realtime: $error');
            }
          },
        )
        .subscribe();
  }

  void _applyRemote(AdminUser admin) {
    final index = _admins.indexWhere((a) => a.id == admin.id);
    if (index >= 0) {
      _admins[index] = admin;
    } else {
      _admins.add(admin);
    }
    if (_current?.id == admin.id) _current = admin;
    _persistCache();
    notifyListeners();
  }

  void _removeRemote(String id) {
    _admins.removeWhere((a) => a.id == id);
    if (_current?.id == id) _current = null;
    _persistCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
