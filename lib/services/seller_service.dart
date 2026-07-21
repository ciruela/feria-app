import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/seller.dart';
import 'supabase_seller_repository.dart';

class SellerService extends ChangeNotifier {
  static const _cacheKey = 'sellers_cache_json';
  static const _selectedKey = 'selected_seller_id';

  List<Seller> _sellers = [];
  Seller? _selected;
  bool _isSyncing = false;

  List<Seller> get sellers =>
      _sellers.where((seller) => seller.activo).toList();
  Seller? get selected => _selected;
  bool get isSyncing => _isSyncing;

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
  }

  Future<void> syncFromCloud() async {
    if (!AppConfig.usesRemoteSellers) return;

    _isSyncing = true;
    notifyListeners();

    try {
      if (AppConfig.useSupabase) {
        _sellers = await _supabaseSellers.fetchAll();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _cacheKey,
          json.encode({
            'sellers': _sellers.map((seller) => seller.toJson()).toList(),
          }),
        );
      } else {
        final response = await http
            .get(Uri.parse(AppConfig.sellersUrl))
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          _parseSellers(response.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, response.body);
        }
      }
    } catch (_) {
      if (_sellers.isEmpty) {
        await _loadFromAssets();
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> selectSeller(Seller seller) async {
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
    _selected = _sellers.where((seller) => seller.id == id).firstOrNull;
  }

  void _parseSellers(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = data['sellers'] as List<dynamic>;
    _sellers = list
        .map((item) => Seller.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
