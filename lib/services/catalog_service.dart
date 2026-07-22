import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import 'excel_catalog_service.dart';
import 'supabase_catalog_repository.dart';
import 'product_photo_service.dart';
import 'supabase_service.dart';

class CatalogService extends ChangeNotifier {
  static const _cacheKey = 'catalog_cache_json';
  static const _lastSyncKey = 'catalog_last_sync';

  List<Product> _products = [];
  DateTime? _lastSync;
  bool _isSyncing = false;
  String? _lastError;
  RealtimeChannel? _realtimeChannel;

  List<Product> get products => List.unmodifiable(_products);
  DateTime? get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  bool get isFromCloud => AppConfig.usesRemoteCatalog;

  final SupabaseCatalogRepository _supabaseCatalog = SupabaseCatalogRepository();
  final ProductPhotoService _productPhotos = ProductPhotoService();

  Future<void> load() async {
    final loadedFromCache = await _loadFromCache();
    if (!loadedFromCache) {
      await _loadFromAssets();
    }

    if (AppConfig.usesRemoteCatalog) {
      await syncFromCloud();
    } else if (_products.isEmpty) {
      await _loadFromAssets();
    }

    if (AppConfig.useSupabase) {
      _subscribeRealtime();
    }
  }

  Future<void> syncFromCloud({bool silent = false}) async {
    if (!AppConfig.usesRemoteCatalog) return;

    if (!silent) {
      _isSyncing = true;
      _lastError = null;
      notifyListeners();
    }

    try {
      if (AppConfig.useSupabase) {
        final remote = await _supabaseCatalog.fetchAll();
        if (silent) {
          if (!_sameProducts(_products, remote)) {
            _products = remote;
            await _persistCache();
            notifyListeners();
          }
        } else {
          _products = remote;
          await _persistCache();
        }
      } else {
        final response = await http
            .get(Uri.parse(AppConfig.catalogUrl))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          throw Exception('Error ${response.statusCode} al bajar el catálogo');
        }

        if (silent) {
          final remote = _parseProductsList(response.body);
          if (!_sameProducts(_products, remote)) {
            _products = remote;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, response.body);
            _lastSync = DateTime.now();
            await prefs.setInt(_lastSyncKey, _lastSync!.millisecondsSinceEpoch);
            notifyListeners();
          }
        } else {
          _parseProducts(response.body);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, response.body);
          _lastSync = DateTime.now();
          await prefs.setInt(_lastSyncKey, _lastSync!.millisecondsSinceEpoch);
        }
      }
    } catch (error) {
      if (silent) {
        debugPrint('CatalogService silent sync: $error');
      } else {
        _lastError = error.toString();
        if (_products.isEmpty) {
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

  Future<bool> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_lastSyncKey);

    if (cached == null) return false;

    _parseProducts(cached);
    _lastSync =
        timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp);
    return _products.isNotEmpty;
  }

  Future<void> _loadFromAssets() async {
    final raw = await rootBundle.loadString('assets/data/products.json');
    _parseProducts(raw);
  }

  void _parseProducts(String raw) {
    _products = _parseProductsList(raw);
  }

  List<Product> _parseProductsList(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final list = data['products'] as List<dynamic>;
    return list
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  bool _sameProducts(List<Product> a, List<Product> b) {
    if (a.length != b.length) return false;
    final aJson = json.encode(a.map((product) => product.toJson()).toList());
    final bJson = json.encode(b.map((product) => product.toJson()).toList());
    return aJson == bJson;
  }

  Future<void> updateProduct(Product updated) async {
    final index = _products.indexWhere((product) => product.id == updated.id);
    if (index == -1) return;

    _products[index] = updated;
    await _persistCache();
    await _pushToSupabase(updated);
    notifyListeners();
  }

  Future<Product> uploadProductPhoto(String productId, File photoFile) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado — no se pueden subir fotos');
    }

    final product = productById(productId);
    if (product == null) {
      throw ArgumentError('Producto no encontrado');
    }

    final storagePath = await _productPhotos.upload(product, photoFile);
    final updated = product.copyWith(
      fotoUrls: [...product.fotoUrls, storagePath],
      foto: '',
    );
    await updateProduct(updated);
    return updated;
  }

  Future<Product> deleteProductPhoto(String productId, String storagePath) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado');
    }

    final product = productById(productId);
    if (product == null) {
      throw ArgumentError('Producto no encontrado');
    }

    final normalized = ProductPhotoService.normalizeForStorage(storagePath);
    final target = ProductPhotoService.stripVersion(normalized);

    await _productPhotos.delete(target);

    final updated = product.copyWith(
      fotoUrls: product.fotoUrls
          .where(
            (path) =>
                ProductPhotoService.stripVersion(
                  ProductPhotoService.normalizeForStorage(path),
                ) !=
                target,
          )
          .toList(),
      foto: '',
    );
    await updateProduct(updated);
    return updated;
  }

  Future<Product> addProduct({
    required ProductType type,
    required String marca,
    required String calibre,
    required String codigo,
    String modelo = '',
    required double precioUsd,
    int? stock,
    List<String> fotoUrls = const [],
  }) async {
    final trimmedMarca = marca.trim();
    final trimmedCalibre = calibre.trim();
    final trimmedCodigo = codigo.trim();
    final trimmedModelo = modelo.trim();

    if (trimmedMarca.isEmpty) {
      throw ArgumentError('Completá la marca');
    }
    if (trimmedCalibre.isEmpty) {
      throw ArgumentError('Completá el calibre');
    }
    if (precioUsd < 0) {
      throw ArgumentError('Precio USD inválido');
    }
    if (stock != null && stock < 0) {
      throw ArgumentError('Stock inválido');
    }

    final row = ExcelProductRow(
      type: type,
      marca: trimmedMarca,
      calibre: trimmedCalibre,
      modelo: trimmedModelo,
      codigo: trimmedCodigo,
      precioUsd: precioUsd,
      stock: stock,
    );

    final isArma =
        type == ProductType.armaCorta || type == ProductType.armaLarga;

    if (!_canCreateFromRow(row)) {
      if (isArma) {
        throw ArgumentError('Completá modelo o ref. interna');
      }
      throw ArgumentError('Completá el código');
    }

    if (_findMatchingRow(row) != null) {
      throw ArgumentError('Ya existe un producto igual en el catálogo');
    }

    final product = Product(
      id: _nextProductId(type),
      type: type,
      marca: trimmedMarca,
      calibre: trimmedCalibre,
      codigo: trimmedCodigo,
      modelo: isArma ? trimmedModelo : '',
      precioUsd: precioUsd,
      stock: stock,
      fotoUrls: fotoUrls
          .map(ProductPhotoService.normalizeForStorage)
          .where((path) => path.isNotEmpty)
          .toList(),
    );

    _products.add(product);
    await _persistCache();
    await _pushToSupabase(product);
    notifyListeners();
    return product;
  }

  String _nextProductId(ProductType type) {
    final prefix = switch (type) {
      ProductType.municion => 'mun',
      ProductType.armaCorta => 'ac',
      ProductType.armaLarga => 'al',
    };

    var max = 0;
    for (final product in _products) {
      if (!product.id.startsWith('$prefix-')) continue;
      final number = int.tryParse(product.id.substring(prefix.length + 1));
      if (number != null && number > max) max = number;
    }

    return '$prefix-${(max + 1).toString().padLeft(3, '0')}';
  }

  Future<void> publishAllToSupabase() async {
    if (!SupabaseService.isConfigured) return;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _supabaseCatalog.upsertAll(_products);
      await _persistCache();
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  String exportJson({bool pretty = true}) {
    final data = {
      'products': _products.map((product) => product.toJson()).toList(),
    };

    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    }

    return json.encode(data);
  }

  Future<ExcelImportResult> importFromExcel(Uint8List bytes) async {
    final parser = ExcelCatalogService();
    final rows = parser.parseRows(bytes);

    var updated = 0;
    var added = 0;
    var skipped = 0;

    for (var i = 0; i < rows.length; i++) {
      try {
        final row = ExcelProductRow.fromMap(rows[i]);
        final existing = _findMatchingRow(row);

        if (existing != null) {
          final index = _products.indexWhere((product) => product.id == existing.id);
          _products[index] = existing.copyWith(
            precioUsd: row.precioUsd > 0 ? row.precioUsd : existing.precioUsd,
            stock: row.stock ?? existing.stock,
            modelo: row.modelo.isNotEmpty ? row.modelo : existing.modelo,
          );
          updated++;
        } else if (_canCreateFromRow(row)) {
          _products.add(row.toNewProduct(i + 1));
          added++;
        } else {
          skipped++;
        }
      } catch (_) {
        skipped++;
      }
    }

    await _persistCache();
    if (SupabaseService.isConfigured) {
      await _supabaseCatalog.upsertAll(_products);
    }
    notifyListeners();
    return ExcelImportResult(updated: updated, added: added, skipped: skipped);
  }

  Uint8List exportToExcel() {
    return ExcelCatalogService().exportProducts(_products);
  }

  Product? _findMatchingRow(ExcelProductRow row) {
    for (final product in _products) {
      if (product.type != row.type) continue;
      if (product.marca.toLowerCase() != row.marca.toLowerCase()) continue;
      if (product.calibre.toLowerCase() != row.calibre.toLowerCase()) continue;

      if (product.isArma) {
        final rowModel = row.modelo.isNotEmpty ? row.modelo : row.codigo;
        if (product.modeloDisplay.toLowerCase() == rowModel.toLowerCase()) {
          return product;
        }
      } else if (product.codigo.toLowerCase() ==
          (row.codigo.isNotEmpty ? row.codigo : row.modelo).toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  bool _canCreateFromRow(ExcelProductRow row) {
    if (row.marca.isEmpty || row.calibre.isEmpty) return false;
    final isArma =
        row.type == ProductType.armaCorta || row.type == ProductType.armaLarga;
    if (isArma) {
      return row.modelo.isNotEmpty || row.codigo.isNotEmpty;
    }
    return row.codigo.isNotEmpty || row.modelo.isNotEmpty;
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, exportJson(pretty: false));
    _lastSync = DateTime.now();
    await prefs.setInt(_lastSyncKey, _lastSync!.millisecondsSinceEpoch);
  }

  Future<void> _pushToSupabase(Product product) async {
    if (!SupabaseService.isConfigured) return;

    try {
      await _supabaseCatalog.upsert(product);
    } catch (error) {
      _lastError = error.toString();
    }
  }

  List<Product> byType(ProductType type) {
    return _products.where((product) => product.type == type).toList();
  }

  List<String> brandsFor(ProductType type) {
    final brands = byType(type).map((product) => product.marca).toSet().toList();
    brands.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return brands;
  }

  List<String> brandsStartingWith(ProductType type, String letter) {
    final normalized = letter.toUpperCase();
    return brandsFor(type)
        .where((brand) => brand.toUpperCase().startsWith(normalized))
        .toList();
  }

  List<String> calibersFor(ProductType type, [String? marca]) {
    final source = marca == null
        ? byType(type)
        : byType(type)
            .where((product) => product.marca.toLowerCase() == marca.toLowerCase());
    final calibers = source.map((product) => product.calibre).toSet().toList();
    calibers.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return calibers;
  }

  Set<String> usedLettersForMarca(ProductType type) {
    return byType(type)
        .map((product) => product.marca.substring(0, 1).toUpperCase())
        .toSet();
  }

  Set<String> usedLettersForCodigo(ProductType type) {
    return byType(type)
        .where((product) => product.codigo.isNotEmpty)
        .map((product) => product.codigo.substring(0, 1).toUpperCase())
        .toSet();
  }

  List<Product> filtered({
    required ProductType type,
    String? marca,
    String? calibre,
    String? marcaLetter,
    String? codigoLetter,
  }) {
    final isMunicion = type == ProductType.municion;

    final results = byType(type).where((product) {
      final marcaOk = marca == null ||
          product.marca.toLowerCase() == marca.toLowerCase();
      final calibreOk = calibre == null ||
          product.calibre.toLowerCase() == calibre.toLowerCase();
      final marcaLetterOk = marcaLetter == null ||
          product.marca.toUpperCase().startsWith(marcaLetter.toUpperCase());
      final codigoLetterOk = !isMunicion ||
          codigoLetter == null ||
          product.codigo.toUpperCase().startsWith(codigoLetter.toUpperCase());
      return marcaOk && calibreOk && marcaLetterOk && codigoLetterOk;
    }).toList();

    results.sort((a, b) {
      final byMarca = a.marca.toLowerCase().compareTo(b.marca.toLowerCase());
      if (byMarca != 0) return byMarca;

      if (a.isArma) {
        return a.modeloDisplay.toLowerCase().compareTo(
              b.modeloDisplay.toLowerCase(),
            );
      }

      return a.codigo.compareTo(b.codigo);
    });

    return results;
  }

  void _subscribeRealtime() {
    if (!SupabaseService.isConfigured) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('public:productos')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          callback: (payload) {
            try {
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                case PostgresChangeEvent.update:
                  final record = payload.newRecord;
                  if (record.isEmpty) return;
                  _applyRemoteProduct(
                    _supabaseCatalog.productFromRow(record),
                  );
                case PostgresChangeEvent.delete:
                  final record = payload.oldRecord;
                  final id = record['id'] as String?;
                  if (id != null) _removeRemoteProduct(id);
                default:
                  break;
              }
            } catch (error) {
              debugPrint('CatalogService realtime: $error');
            }
          },
        )
        .subscribe();
  }

  void _applyRemoteProduct(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    } else {
      _products.add(product);
    }

    _lastSync = DateTime.now();
    _persistCache();
    notifyListeners();
  }

  void _removeRemoteProduct(String productId) {
    _products.removeWhere((product) => product.id == productId);
    _lastSync = DateTime.now();
    _persistCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
