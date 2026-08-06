import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/audit_entry.dart';
import '../models/seller.dart';
import '../utils/ids.dart';
import '../utils/tenant_cache.dart';
import 'audit_service.dart';
import 'supabase_seller_repository.dart';
import 'supabase_service.dart';

class SellerService extends ChangeNotifier {
  static const _cacheKeyBase = 'sellers_cache_json';
  static const _selectedKeyBase = 'selected_seller_id';

  List<Seller> _sellers = [];
  Seller? _selected;
  bool _isSyncing = false;
  String? _lastError;
  RealtimeChannel? _realtimeChannel;
  String? _tenantScope;

  List<Seller> get sellers =>
      _sellers.where((seller) => seller.activo).toList();

  List<Seller> get allSellers {
    final list = List<Seller>.from(_sellers);
    list.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return list;
  }

  int get activeCount => sellers.length;

  int get inactiveCount => _sellers.where((seller) => !seller.activo).length;

  Seller? get selected => _selected;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  bool get hasTenantScope =>
      !AppConfig.useSupabase ||
      (_tenantScope != null && _tenantScope!.isNotEmpty);

  String get _cacheKey => tenantCacheKey(_cacheKeyBase, _tenantScope);
  String get _selectedKey => tenantCacheKey(_selectedKeyBase, _tenantScope);

  final SupabaseSellerRepository _supabaseSellers = SupabaseSellerRepository();

  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    if (_tenantScope == next) return;
    _tenantScope = next;
    _sellers = [];
    _selected = null;
    _lastError = null;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  Future<void> load() async {
    if (AppConfig.useSupabase && !hasTenantScope) return;

    final loaded = await _loadFromCache();
    if (!loaded && !AppConfig.useSupabase) {
      await _loadFromAssets();
    }
    await _loadSelected();
    if (AppConfig.usesRemoteSellers) {
      await syncFromCloud();
    }
    if (AppConfig.useSupabase) {
      _subscribeRealtime();
    }
  }

  Future<void> syncFromCloud({bool silent = false}) async {
    if (!AppConfig.usesRemoteSellers) return;

    if (!silent) {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();
    }

    try {
      if (AppConfig.useSupabase) {
        final remote = await _supabaseSellers.fetchAll();
        if (silent) {
          if (!_sameSellers(_sellers, remote)) {
            _sellers = remote;
            await _persistCache();
            await _loadSelected();
            notifyListeners();
          }
        } else {
          _sellers = remote;
          await _persistCache();
        }
      } else {
        final response = await http
            .get(Uri.parse(AppConfig.sellersUrl))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (silent) {
            final remote = _parseSellersList(response.body);
            if (!_sameSellers(_sellers, remote)) {
              _sellers = remote;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_cacheKey, response.body);
              await _loadSelected();
              notifyListeners();
            }
          } else {
            _parseSellers(response.body);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, response.body);
          }
        }
      }
      if (!silent) {
        await _loadSelected();
      }
    } catch (error) {
      if (silent) {
        debugPrint('SellerService silent sync: $error');
      } else {
        _lastError = error.toString();
        if (_sellers.isEmpty && !AppConfig.useSupabase) {
          await _loadFromAssets();
        }
      }
    } finally {
      if (!silent) {
        _isSyncing = false;
        notifyListeners();
      }
    }
  }

  Future<Seller> addSeller(String nombre) async {
    final trimmed = nombre.trim().toUpperCase();
    if (trimmed.length < 2) {
      throw ArgumentError('El nombre debe tener al menos 2 caracteres');
    }

    final exists = _sellers.any(
      (seller) => seller.nombre.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      throw ArgumentError('Ya existe un vendedor con ese nombre');
    }

    final seller = Seller(
      id: _nextId(),
      nombre: trimmed,
      activo: true,
    );

    if (SupabaseService.isConfigured) {
      try {
        await _supabaseSellers.upsert(seller);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }

    _sellers.add(seller);
    await _persistCache();
    AuditService.instance.log(
      accion: 'Agregó vendedor',
      entidad: AuditEntidad.vendedor,
      entidadId: seller.id,
      detalle: seller.nombre,
    );
    notifyListeners();
    return seller;
  }

  Future<void> deactivateSeller(String id) async {
    await _setActive(id, active: false);
  }

  Future<void> reactivateSeller(String id) async {
    await _setActive(id, active: true);
  }

  Future<void> deleteSeller(String id) async {
    final index = _sellers.indexWhere((seller) => seller.id == id);
    if (index == -1) return;

    final removed = _sellers[index];
    _sellers.removeAt(index);
    if (_selected?.id == id) {
      await clearSelection();
    }

    await _persistCache();
    if (SupabaseService.isConfigured) {
      try {
        await _supabaseSellers.delete(id);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }
    AuditService.instance.log(
      accion: 'Eliminó vendedor',
      entidad: AuditEntidad.vendedor,
      entidadId: id,
      detalle: removed.nombre,
    );
    notifyListeners();
  }

  Future<void> updateSellerName(String id, String nombre) async {
    final trimmed = nombre.trim().toUpperCase();
    if (trimmed.length < 2) {
      throw ArgumentError('El nombre debe tener al menos 2 caracteres');
    }

    final index = _sellers.indexWhere((seller) => seller.id == id);
    if (index == -1) return;

    final current = _sellers[index];
    if (current.nombre.toLowerCase() == trimmed.toLowerCase()) return;

    final exists = _sellers.any(
      (seller) =>
          seller.id != id &&
          seller.nombre.toLowerCase() == trimmed.toLowerCase(),
    );
    if (exists) {
      throw ArgumentError('Ya existe un vendedor con ese nombre');
    }

    final updated = current.copyWith(nombre: trimmed);
    _sellers[index] = updated;
    if (_selected?.id == id) {
      _selected = updated;
    }

    await _persistCache();
    if (SupabaseService.isConfigured) {
      try {
        await _supabaseSellers.updateName(id, trimmed);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }
    AuditService.instance.log(
      accion: 'Renombró vendedor',
      entidad: AuditEntidad.vendedor,
      entidadId: id,
      detalle: '${current.nombre} → $trimmed',
    );
    notifyListeners();
  }

  Future<void> _setActive(String id, {required bool active}) async {
    final index = _sellers.indexWhere((seller) => seller.id == id);
    if (index == -1) return;

    final nombre = _sellers[index].nombre;
    _sellers[index] = _sellers[index].copyWith(activo: active);
    if (!active && _selected?.id == id) {
      await clearSelection();
    }

    await _persistCache();
    if (SupabaseService.isConfigured) {
      try {
        await _supabaseSellers.setActive(id, activo: active);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }
    AuditService.instance.log(
      accion: active ? 'Reactivó vendedor' : 'Desactivó vendedor',
      entidad: AuditEntidad.vendedor,
      entidadId: id,
      detalle: nombre,
    );
    notifyListeners();
  }

  Future<void> selectSeller(Seller seller) async {
    if (!seller.activo) return;
    _selected = seller;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedKey, seller.id);
    } catch (_) {
      // Persistencia opcional: la sesión actual sigue con _selected en memoria.
    }
  }

  Future<void> clearSelection() async {
    _selected = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedKey);
    notifyListeners();
  }

  String _nextId() => newId('v');

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;

    final tenantId = _tenantScope?.trim();
    _realtimeChannel?.unsubscribe();
    var channel = SupabaseService.client.channel(
      'vendedores:${tenantId ?? 'all'}',
    );
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'vendedores',
      filter: tenantId == null || tenantId.isEmpty
          ? null
          : PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'tenant_id',
              value: tenantId,
            ),
      callback: (payload) {
        try {
          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
            case PostgresChangeEvent.update:
              final record = payload.newRecord;
              if (record.isEmpty) return;
              _applyRemoteSeller(
                _supabaseSellers.sellerFromRow(record),
              );
            case PostgresChangeEvent.delete:
              final id = payload.oldRecord['id'] as String?;
              if (id != null) _removeRemoteSeller(id);
            default:
              break;
          }
        } catch (error) {
          debugPrint('SellerService realtime: $error');
        }
      },
    );
    _realtimeChannel = channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('SellerService realtime status=$status error=$error');
        unawaited(syncFromCloud(silent: true));
      }
    });
  }

  void _applyRemoteSeller(Seller seller) {
    final index = _sellers.indexWhere((item) => item.id == seller.id);
    if (index >= 0) {
      _sellers[index] = seller;
    } else {
      _sellers.add(seller);
    }

    if (_selected?.id == seller.id && !seller.activo) {
      _selected = null;
    }

    _persistCache();
    notifyListeners();
  }

  void _removeRemoteSeller(String id) {
    _sellers.removeWhere((seller) => seller.id == id);
    if (_selected?.id == id) {
      _selected = null;
    }
    _persistCache();
    notifyListeners();
  }

  Future<bool> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return false;
    _parseSellers(cached);
    return _sellers.isNotEmpty;
  }

  Future<void> _loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/data/sellers.json');
    _parseSellers(raw);
  }

  Future<void> _loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_selectedKey);
    if (id == null) return;
    _selected = _sellers
        .where((seller) => seller.id == id && seller.activo)
        .firstOrNull;
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      json.encode({
        'sellers': _sellers.map((seller) => seller.toJson()).toList(),
      }),
    );
  }

  void _parseSellers(String raw) {
    _sellers = _parseSellersList(raw);
  }

  List<Seller> _parseSellersList(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = data['sellers'] as List<dynamic>;
    return list
        .map((item) => Seller.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  bool _sameSellers(List<Seller> a, List<Seller> b) {
    if (a.length != b.length) return false;
    final aJson = json.encode(a.map((seller) => seller.toJson()).toList());
    final bJson = json.encode(b.map((seller) => seller.toJson()).toList());
    return aJson == bJson;
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
