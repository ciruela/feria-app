import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/audit_entry.dart';
import '../models/product.dart';
import '../models/stock_movimiento.dart';
import '../utils/app_logger.dart';
import '../utils/ids.dart';
import '../utils/jwt.dart';
import 'audit_service.dart';
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
    } catch (error, stackTrace) {
      if (silent) {
        AppLogger.warn('Sync silencioso de catálogo falló',
            error: error, stackTrace: stackTrace);
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

    final previous = _products[index];
    _products[index] = updated;
    await _persistCache();
    await _pushToSupabase(updated);

    if (SupabaseService.isConfigured &&
        previous.stock != null &&
        updated.stock != null &&
        previous.stock != updated.stock) {
      await _supabaseCatalog.logStockChange(
        productId: updated.id,
        delta: updated.stock! - previous.stock!,
        motivo: StockMotivo.ajuste,
        stockAntes: previous.stock,
        stockDespues: updated.stock,
        nota: 'Ajuste manual desde admin',
      );
    }

    _auditProductUpdate(previous, updated);

    notifyListeners();
  }

  void _auditProductUpdate(Product previous, Product updated) {
    final label = updated.isArma ? updated.modeloDisplay : updated.codigo;
    final tag = '${updated.marca} $label';

    if (previous.precioUsd != updated.precioUsd) {
      AuditService.instance.log(
        accion: 'Cambió precio',
        entidad: AuditEntidad.precio,
        entidadId: updated.id,
        detalle: '$tag · USD ${previous.precioUsd} → ${updated.precioUsd}',
      );
    }

    final changes = <String>[];
    if (previous.stock != updated.stock) {
      changes.add('stock ${previous.stock ?? '—'} → ${updated.stock ?? '—'}');
    }
    if (previous.calibre != updated.calibre) changes.add('calibre');
    if (previous.codigo != updated.codigo) changes.add('código');
    if (previous.modelo != updated.modelo) changes.add('modelo');
    if (previous.descripcion != updated.descripcion) changes.add('descripción');
    if (previous.roundsPerBox != updated.roundsPerBox) {
      changes.add('balas/caja');
    }

    if (changes.isNotEmpty) {
      AuditService.instance.log(
        accion: 'Editó producto',
        entidad: AuditEntidad.producto,
        entidadId: updated.id,
        detalle: '$tag · ${changes.join(', ')}',
      );
    }
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
    String descripcion = '',
    required double precioUsd,
    int? stock,
    int? roundsPerBox,
    List<String> fotoUrls = const [],
  }) async {
    final trimmedMarca = marca.trim();
    final trimmedCalibre = calibre.trim();
    final trimmedCodigo = codigo.trim();
    final trimmedModelo = modelo.trim();
    final trimmedDescripcion = descripcion.trim();
    final isMunicion = type == ProductType.municion;

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
    if (isMunicion && (roundsPerBox == null || roundsPerBox <= 0)) {
      throw ArgumentError('Completá las balas por caja');
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
      descripcion: trimmedDescripcion,
      precioUsd: precioUsd,
      stock: stock,
      stockInicial: stock,
      roundsPerBox: isMunicion ? roundsPerBox : null,
      fotoUrls: fotoUrls
          .map(ProductPhotoService.normalizeForStorage)
          .where((path) => path.isNotEmpty)
          .toList(),
    );

    _products.add(product);
    await _persistCache();
    await _pushToSupabase(product);

    if (SupabaseService.isConfigured && stock != null && stock > 0) {
      await _supabaseCatalog.logStockChange(
        productId: product.id,
        delta: stock,
        motivo: StockMotivo.carga,
        stockAntes: 0,
        stockDespues: stock,
        nota: 'Alta de producto',
      );
    }

    final label = isArma ? product.modeloDisplay : product.codigo;
    AuditService.instance.log(
      accion: 'Creó producto',
      entidad: AuditEntidad.producto,
      entidadId: product.id,
      detalle: '${product.marca} $label · '
          '${product.type.label} · stock ${stock ?? '—'}',
    );

    notifyListeners();
    return product;
  }

  Future<void> deleteProduct(String productId) async {
    final product = productById(productId);
    if (product == null) {
      throw ArgumentError('Producto no encontrado');
    }

    if (SupabaseService.isConfigured) {
      for (final path in product.fotoUrls) {
        try {
          await _productPhotos.delete(path);
        } catch (error) {
          debugPrint('No se pudo borrar foto $path: $error');
        }
      }

      try {
        await _supabaseCatalog.delete(productId);
      } catch (error) {
        _lastError = error.toString();
        rethrow;
      }
    }

    _products.removeWhere((item) => item.id == productId);
    await _persistCache();

    final label = product.isArma ? product.modeloDisplay : product.codigo;
    AuditService.instance.log(
      accion: 'Eliminó producto',
      entidad: AuditEntidad.producto,
      entidadId: productId,
      detalle: '${product.marca} $label · ${product.type.label}',
    );

    notifyListeners();
  }

  String _nextProductId(ProductType type) {
    final prefix = switch (type) {
      ProductType.municion => 'mun',
      ProductType.armaCorta => 'ac',
      ProductType.armaLarga => 'al',
    };

    // ID globalmente unico: en multi-tenant no puede ser secuencial por tenant
    // (colisionaria con otras armerias, la PK de productos es global).
    return newId(prefix);
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
    final changedProducts = <Product>[];

    for (var i = 0; i < rows.length; i++) {
      try {
        final row = ExcelProductRow.fromMap(rows[i]);
        final existing = _findMatchingRow(row);

        if (existing != null) {
          final index = _products.indexWhere((product) => product.id == existing.id);
          final newStock = row.stock ?? existing.stock;
          final product = existing.copyWith(
            precioUsd: row.precioUsd > 0 ? row.precioUsd : existing.precioUsd,
            stock: newStock,
            calibre: row.calibre.isNotEmpty ? row.calibre : existing.calibre,
            modelo: row.modelo.isNotEmpty ? row.modelo : existing.modelo,
            descripcion: row.descripcion.isNotEmpty
                ? row.descripcion
                : existing.descripcion,
            roundsPerBox: existing.isMunicion
                ? (row.roundsPerBox ?? existing.roundsPerBox)
                : existing.roundsPerBox,
            stockInicial: existing.stockInicial ?? newStock,
          );
          _products[index] = product;
          changedProducts.add(product);
          updated++;
        } else if (_canCreateFromRow(row)) {
          final product = _productFromExcelRow(row);
          _products.add(product);
          changedProducts.add(product);
          added++;
        } else {
          skipped++;
        }
      } catch (e, s) {
        skipped++;
        AppLogger.warn('Fila de Excel omitida por error de parseo',
            error: e, stackTrace: s);
      }
    }

    await _persistCache();
    if (SupabaseService.isConfigured && changedProducts.isNotEmpty) {
      await _ensureSupabaseWriteContext();
      await _supabaseCatalog.upsertAll(changedProducts);
    }

    AuditService.instance.log(
      accion: 'Importó Excel',
      entidad: AuditEntidad.excel,
      detalle: '$updated actualizados · $added nuevos · $skipped omitidos',
    );

    notifyListeners();
    return ExcelImportResult(updated: updated, added: added, skipped: skipped);
  }

  Uint8List exportToExcel() {
    return ExcelCatalogService().exportProducts(_products);
  }

  /// Producto nuevo desde Excel con ID global único (multi-tenant).
  Product _productFromExcelRow(ExcelProductRow row) {
    return Product(
      id: _nextProductId(row.type),
      type: row.type,
      marca: row.marca,
      calibre: row.calibre,
      codigo: row.codigo.isNotEmpty
          ? row.codigo
          : (row.modelo.isNotEmpty ? row.modelo : 'item'),
      modelo: row.modelo,
      descripcion: row.descripcion,
      precioUsd: row.precioUsd,
      stock: row.stock,
      stockInicial: row.stock,
      roundsPerBox: row.isMunicion ? row.roundsPerBox : null,
    );
  }

  /// RLS exige tenant activo en el JWT (o platform admin) para escribir productos.
  Future<void> _ensureSupabaseWriteContext() async {
    if (!SupabaseService.isConfigured) return;
    await SupabaseService.client.auth.refreshSession();
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      throw StateError('No hay sesión activa. Volvé a iniciar sesión.');
    }
    final claims = decodeJwtPayload(session.accessToken);
    final tenantId = (claims['tenant_id'] as String?)?.trim();
    final platformAdmin = claims['is_platform_admin'];
    final isPlatformAdmin =
        platformAdmin == true || platformAdmin == 'true';
    if ((tenantId == null || tenantId.isEmpty) && !isPlatformAdmin) {
      throw StateError(
        'No hay armería activa en la sesión. '
        'Volvé al selector y elegí una organización antes de importar.',
      );
    }
  }

  Product? _findMatchingRow(ExcelProductRow row) {
    for (final product in _products) {
      if (product.type != row.type) continue;
      if (product.marca.toLowerCase() != row.marca.toLowerCase()) continue;
      // El calibre solo desempata si ambos lo tienen (las planillas CCI no lo traen).
      if (product.calibre.isNotEmpty &&
          row.calibre.isNotEmpty &&
          product.calibre.toLowerCase() != row.calibre.toLowerCase()) {
        continue;
      }

      if (product.isArma) {
        final rowModel = row.modelo.isNotEmpty ? row.modelo : row.codigo;
        if (product.modeloDisplay.toLowerCase() == rowModel.toLowerCase()) {
          return product;
        }
      } else {
        // Munición: matchear por código; si no hay, por modelo o descripción.
        final rowKey = row.codigo.isNotEmpty
            ? row.codigo
            : (row.modelo.isNotEmpty ? row.modelo : row.descripcion);
        if (rowKey.isEmpty) continue;
        final key = rowKey.toLowerCase();
        if (product.codigo.toLowerCase() == key ||
            product.descripcion.toLowerCase() == key) {
          return product;
        }
      }
    }
    return null;
  }

  bool _canCreateFromRow(ExcelProductRow row) {
    if (row.marca.isEmpty) return false;
    final isArma =
        row.type == ProductType.armaCorta || row.type == ProductType.armaLarga;
    if (isArma) {
      // Las armas sí necesitan calibre e identificación.
      if (row.calibre.isEmpty) return false;
      return row.modelo.isNotEmpty || row.codigo.isNotEmpty;
    }
    // Munición: alcanza con código, modelo o descripción (calibre opcional).
    return row.codigo.isNotEmpty ||
        row.modelo.isNotEmpty ||
        row.descripcion.isNotEmpty;
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
