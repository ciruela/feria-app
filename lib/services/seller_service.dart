import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/seller.dart';
import 'supabase_seller_repository.dart';
import 'supabase_service.dart';

class SellerService extends ChangeNotifier {
  static const _cacheKey = 'sellers_cache_json';
  static const _selectedKey = 'selected_seller_id';

  List<Seller> _sellers = [];
  Seller? _selected;
  bool _isSyncing = false;
  String? _lastError;
  RealtimeChannel? _realtimeChannel;

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

  final SupabaseSellerRepository _supabaseSellers = SupabaseSellerRepository();

  Future<void> load() async {
    final loaded = await _loadFromCache();
    if (!loaded) {
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
        if (_sellers.isEmpty) {
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

    _sellers.add(seller);
    await _persistCache();
    await _pushToSupabase(seller);
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
      await _supabaseSellers.updateName(id, trimmed);
    }
    notifyListeners();
  }

  Future<void> _setActive(String id, {required bool active}) async {
    final index = _sellers.indexWhere((seller) => seller.id == id);
    if (index == -1) return;

    _sellers[index] = _sellers[index].copyWith(activo: active);
    if (!active && _selected?.id == id) {
      await clearSelection();
    }

    await _persistCache();
    if (SupabaseService.isConfigured) {
      await _supabaseSellers.setActive(id, activo: active);
    }
    notifyListeners();
  }

  Future<void> selectSeller(Seller seller) async {
    if (!seller.activo) return;
    _selected = seller;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, seller.id);
    notifyListeners();
  }

  Future<void> clearSelection() async {
    _selected = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedKey);
    notifyListeners();
  }

  String _nextId() {
    var max = 0;
    for (final seller in _sellers) {
      if (seller.id.startsWith('v')) {
        final number = int.tryParse(seller.id.substring(1));
        if (number != null && number > max) max = number;
      }
    }
    return 'v${max + 1}';
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('public:vendedores')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vendedores',
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
        )
        .subscribe();
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

  Future<void> _pushToSupabase(Seller seller) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await _supabaseSellers.upsert(seller);
    } catch (error) {
      _lastError = error.toString();
    }
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
