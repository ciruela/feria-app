import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/audit_entry.dart';
import '../models/product.dart';
import '../models/product_search_index.dart';
import '../models/stock_movimiento.dart';
import '../utils/app_logger.dart';
import '../utils/ids.dart';
import '../utils/jwt.dart';
import '../utils/product_id_remap.dart';
import '../utils/tenant_cache.dart';
import 'audit_service.dart';
import 'excel_catalog_service.dart';
import 'supabase_catalog_repository.dart';
import 'product_photo_service.dart';
import 'stock_errors.dart';
import 'supabase_service.dart';

/// Progreso de una importación de Excel: [done] de [total] en la fase [phase].
/// [total] == 0 significa fase indeterminada (aún preparando).
typedef ImportProgress = void Function(int done, int total, String phase);

class CatalogService extends ChangeNotifier {
  static const _cacheKeyBase = 'catalog_cache_json';
  static const _lastSyncKeyBase = 'catalog_last_sync';

  List<Product> _products = [];
  DateTime? _lastSync;
  bool _isSyncing = false;
  String? _lastError;
  RealtimeChannel? _realtimeChannel;
  String? _tenantScope;

  /// Índices de búsqueda cacheados por id de producto. Se invalidan (limpian)
  /// ante cualquier cambio del catálogo vía [notifyListeners], de modo que el
  /// buscador no recalcule las normalizaciones en cada tecla.
  final Map<String, ProductSearchIndex> _searchIndexCache = {};

  List<Product> get products => List.unmodifiable(_products);
  DateTime? get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  bool get isFromCloud => AppConfig.usesRemoteCatalog;
  bool get hasTenantScope =>
      !AppConfig.useSupabase ||
      (_tenantScope != null && _tenantScope!.isNotEmpty);

  String get _cacheKey => tenantCacheKey(_cacheKeyBase, _tenantScope);
  String get _lastSyncKey => tenantCacheKey(_lastSyncKeyBase, _tenantScope);

  /// Aísla cache y datos por armería. Llamar antes de [load] al elegir tenant.
  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    if (_tenantScope == next) return;
    _tenantScope = next;
    _products = [];
    _lastSync = null;
    _lastError = null;
    _searchIndexCache.clear();
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  Future<void> load() async {
    if (AppConfig.useSupabase && !hasTenantScope) return;

    final loadedFromCache = await _loadFromCache();
    if (!loadedFromCache && !AppConfig.useSupabase) {
      await _loadFromAssets();
    }

    if (AppConfig.usesRemoteCatalog) {
      await syncFromCloud();
    } else if (_products.isEmpty && !AppConfig.useSupabase) {
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
        final remote = await _supabaseCatalog.fetchAll(tenantId: _tenantScope);
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
        if (_products.isEmpty && !AppConfig.useSupabase) {
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
    try {
      await _pushToSupabase(updated);
    } catch (error) {
      // Si el upsert falla (RLS, grants, red), no dejamos la foto/ficha
      // "guardada" solo en caché local: el usuario vería el ok y al sync se pierde.
      _products[index] = previous;
      await _persistCache();
      notifyListeners();
      rethrow;
    }

    if (SupabaseService.isConfigured &&
        updated.stock != null &&
        previous.stock != updated.stock) {
      try {
        final next = await _supabaseCatalog.setStock(
          updated.id,
          updated.stock!,
          motivo:
              previous.stock == null ? StockMotivo.carga : StockMotivo.ajuste,
          nota: 'Ajuste manual desde admin',
          label: _productStockLabel(updated),
        );
        _products[index] = updated.copyWith(stock: next);
        await _persistCache();
      } catch (error, stackTrace) {
        // AR-19: ficha puede haberse guardado; el stock NO se da por ok.
        _products[index] = updated.copyWith(stock: previous.stock);
        await _persistCache();
        notifyListeners();
        AppLogger.error(
          'Ajuste de stock falló; movimiento no registrado',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
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

  Future<Product> uploadProductPhoto(
    String productId,
    Uint8List photoBytes, {
    String? fileName,
  }) async {
    if (!SupabaseService.isConfigured) {
      throw StateError('Supabase no configurado — no se pueden subir fotos');
    }

    final product = productById(productId);
    if (product == null) {
      throw ArgumentError('Producto no encontrado');
    }

    await _ensureSupabaseWriteContext();

    final storagePath = await _productPhotos.uploadBytes(
      product,
      photoBytes,
      fileName: fileName,
    );
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

    // AR-35: if a soft-deleted row owns this codigo, restore it (same id).
    Product? inactive;
    if (SupabaseService.isConfigured && trimmedCodigo.isNotEmpty) {
      inactive = await _supabaseCatalog
          .fetchByCodigoIncludingInactive(trimmedCodigo);
    }

    final product = Product(
      id: inactive?.id ?? _nextProductId(type),
      type: type,
      marca: trimmedMarca,
      calibre: trimmedCalibre,
      codigo: trimmedCodigo,
      modelo: isArma ? trimmedModelo : '',
      descripcion: trimmedDescripcion,
      precioUsd: precioUsd,
      stock: stock,
      stockInicial: inactive?.stockInicial ?? stock,
      roundsPerBox: isMunicion ? roundsPerBox : null,
      fotoUrls: fotoUrls.isNotEmpty
          ? fotoUrls
              .map(ProductPhotoService.normalizeForStorage)
              .where((path) => path.isNotEmpty)
              .toList()
          : (inactive?.fotoUrls ?? const []),
      foto: fotoUrls.isEmpty ? (inactive?.foto ?? '') : '',
    );

    _products.add(product);
    await _persistCache();
    final persistedId = await _pushToSupabase(product) ?? product.id;
    var saved = product;
    if (persistedId != product.id) {
      saved = product.copyWith(id: persistedId);
      final index = _products.indexWhere((item) => item.id == persistedId);
      if (index == -1) {
        final stale = _products.indexWhere((item) => item.id == product.id);
        if (stale != -1) _products[stale] = saved;
      } else {
        saved = _products[index];
      }
    }

    if (SupabaseService.isConfigured && stock != null) {
      try {
        final next = await _supabaseCatalog.setStock(
          saved.id,
          stock,
          motivo: StockMotivo.carga,
          nota: inactive != null ? 'Reactivación de producto' : 'Alta de producto',
          label: _productStockLabel(saved),
        );
        final index = _products.indexWhere((item) => item.id == saved.id);
        if (index != -1) {
          saved = saved.copyWith(stock: next);
          _products[index] = saved;
          await _persistCache();
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'Alta de producto sin movimiento de stock',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    final label = isArma ? saved.modeloDisplay : saved.codigo;
    AuditService.instance.log(
      accion: inactive != null ? 'Reactivó producto' : 'Creó producto',
      entidad: AuditEntidad.producto,
      entidadId: saved.id,
      detalle: '${saved.marca} $label · '
          '${saved.type.label} · stock ${stock ?? '—'}',
    );

    notifyListeners();
    return saved;
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

  /// Índice de búsqueda del producto, computado una vez y cacheado por id.
  /// La caché se limpia en [notifyListeners] cuando cambia el catálogo.
  ProductSearchIndex searchIndexFor(Product product) {
    return _searchIndexCache.putIfAbsent(
      product.id,
      () => ProductSearchIndex.fromProduct(product),
    );
  }

  String _productStockLabel(Product product) {
    if (product.isArma) {
      return '${product.marca} ${product.modeloDisplay}'.trim();
    }
    if (product.codigo.isNotEmpty) {
      return '${product.marca} ${product.codigo}';
    }
    return product.marca;
  }

  /// Valida cantidades contra el catálogo actual (llamar tras [syncFromCloud]).
  String? validateSaleQuantities(Map<String, int> quantities) {
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;

      final product = productById(entry.key);
      if (product == null) {
        return 'Producto ${entry.key} no está en el catálogo.';
      }

      final stock = product.stock;
      final label = _productStockLabel(product);
      if (stock == null) {
        return StockNotTrackedException(productId: product.id, label: label)
            .toString();
      }
      if (stock < entry.value) {
        return InsufficientStockException(
          productId: product.id,
          requested: entry.value,
          available: stock,
          label: label,
        ).toString();
      }
    }
    return null;
  }

  void _setLocalStock(String productId, int stock) {
    final index = _products.indexWhere((product) => product.id == productId);
    if (index == -1) return;
    _products[index] = _products[index].copyWith(stock: stock);
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

  /// Interpreta el Excel sin escribir nada, para que el admin revise los datos
  /// (marca, calibre, modelo, código, precio, stock) antes de confirmar.
  ExcelImportPreview previewExcel(Uint8List bytes) {
    final parser = ExcelCatalogService();
    final rawRows = parser.parseRows(bytes);
    final rows = <ExcelImportPreviewRow>[];
    var unreadable = 0;
    final seenCodes = <String>{};

    for (final raw in rawRows) {
      try {
        final row = ExcelProductRow.fromMap(raw);
        final existing = _findMatchingRow(row);
        final warnings = <String>[];

        if (row.marca.isEmpty) {
          warnings.add('Sin marca (poné título o Marca: en la hoja)');
        }
        if (row.precioUsd <= 0) {
          warnings.add(
            existing != null
                ? 'Precio USD 0 (se conserva el actual)'
                : 'Precio USD 0',
          );
        }
        if (existing == null && row.stock == null) {
          warnings.add('Sin stock');
        }
        if (existing != null &&
            row.marca.isNotEmpty &&
            existing.marca.toLowerCase() != row.marca.toLowerCase()) {
          warnings.add('Marca distinta: hoy ${existing.marca}');
        }
        final codeKey = row.codigo.trim().toLowerCase();
        if (codeKey.isNotEmpty && !seenCodes.add(codeKey)) {
          warnings.add('Código repetido en el Excel');
        }

        final action = existing != null
            ? ExcelImportAction.update
            : (_canCreateFromRow(row)
                ? ExcelImportAction.create
                : ExcelImportAction.skip);
        if (action == ExcelImportAction.skip && row.marca.isEmpty) {
          warnings.add('Se omite: falta marca');
        }

        rows.add(
          ExcelImportPreviewRow(
            row: row,
            action: action,
            existingId: existing?.id,
            warnings: warnings,
            existingStock: existing?.stock,
            existingMarca: existing?.marca,
          ),
        );
      } catch (_) {
        unreadable++;
      }
    }

    return ExcelImportPreview(rows: rows, unreadable: unreadable);
  }

  Future<ExcelImportResult> importFromExcel(
    Uint8List bytes, {
    ImportProgress? onProgress,
  }) async {
    onProgress?.call(0, 0, 'Preparando…');
    // Catálogo fresco del servidor para no duplicar por caché vieja.
    if (SupabaseService.isConfigured) {
      await syncFromCloud(silent: true);
    }

    final parser = ExcelCatalogService();
    final rows = parser.parseRows(bytes);

    var updated = 0;
    var added = 0;
    var skipped = 0;
    final changedProducts = <Product>[];
    final stockTargetById = <String, int?>{};
    final matchedIds = <String>[];

    // Pre-scan: active matches + soft-deleted by codigo (AR-35).
    final inactiveByCodigo = <String, Product>{};
    if (SupabaseService.isConfigured) {
      await _ensureSupabaseWriteContext();
      for (final raw in rows) {
        try {
          final row = ExcelProductRow.fromMap(raw);
          final existing = _findMatchingRow(row);
          if (existing != null) {
            matchedIds.add(existing.id);
            continue;
          }
          final codigo = row.codigo.trim();
          if (codigo.isEmpty) continue;
          final key = codigo.toLowerCase();
          if (inactiveByCodigo.containsKey(key)) continue;
          final inactive =
              await _supabaseCatalog.fetchByCodigoIncludingInactive(codigo);
          if (inactive != null) {
            inactiveByCodigo[key] = inactive;
            matchedIds.add(inactive.id);
          }
        } catch (_) {
          // Se contabiliza skipped en el loop principal.
        }
      }
    } else {
      for (final raw in rows) {
        try {
          final row = ExcelProductRow.fromMap(raw);
          final existing = _findMatchingRow(row);
          if (existing != null) matchedIds.add(existing.id);
        } catch (_) {}
      }
    }

    Map<String, int?> serverStocks = {};
    if (SupabaseService.isConfigured && matchedIds.isNotEmpty) {
      serverStocks = await _supabaseCatalog.fetchStocksByIds(matchedIds);
    }

    for (var i = 0; i < rows.length; i++) {
      try {
        final row = ExcelProductRow.fromMap(rows[i]);
        final existing = _findMatchingRow(row);
        final inactive = existing == null
            ? inactiveByCodigo[row.codigo.trim().toLowerCase()]
            : null;
        final base = existing ?? inactive;

        if (base != null) {
          final index =
              _products.indexWhere((product) => product.id == base.id);
          final serverStock = serverStocks.containsKey(base.id)
              ? serverStocks[base.id]
              : base.stock;
          final newStock = row.stock ?? serverStock;
          stockTargetById[base.id] = newStock;
          // Actualiza ficha/stock del Excel. Fotos se preservan (copyWith no
          // las toca) y el upsert a Supabase tampoco escribe columnas foto*.
          // Soft-deleted (AR-35): same id, upsert sets activo=true.
          final product = base.copyWith(
            marca: row.marca.isNotEmpty ? row.marca : base.marca,
            precioUsd: row.precioUsd > 0 ? row.precioUsd : base.precioUsd,
            fixedPrices: row.fixedPrices ?? base.fixedPrices,
            stock: newStock,
            calibre: row.calibre.isNotEmpty ? row.calibre : base.calibre,
            modelo: row.modelo.isNotEmpty ? row.modelo : base.modelo,
            descripcion: row.descripcion.isNotEmpty
                ? row.descripcion
                : base.descripcion,
            roundsPerBox: base.isMunicion
                ? (row.roundsPerBox ?? base.roundsPerBox)
                : base.roundsPerBox,
            stockInicial: base.stockInicial ?? newStock,
          );
          if (index >= 0) {
            _products[index] = product;
            updated++;
          } else {
            _products.add(product);
            added++;
          }
          changedProducts.add(product);
        } else if (_canCreateFromRow(row)) {
          final product = _productFromExcelRow(row);
          stockTargetById[product.id] = product.stock;
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
      // Import Excel: nunca pisar fotos en DB (aunque la caché local esté vacía).
      final remapped = await _supabaseCatalog.upsertAll(
        changedProducts,
        updatePhotos: false,
        onProgress: (done, total) =>
            onProgress?.call(done, total, 'Guardando productos'),
      );
      applyProductIdRemaps(
        remapped,
        products: _products,
        changedProducts: changedProducts,
        stockTargetById: stockTargetById,
        serverStocks: serverStocks,
      );

      // Solo los que realmente cambian de stock (para un total exacto en la barra).
      final stockUpdates = changedProducts.where((product) {
        final newStock = stockTargetById[product.id];
        if (newStock == null) return false;
        final before = serverStocks.containsKey(product.id)
            ? serverStocks[product.id]
            : null;
        return before != newStock;
      }).toList();

      var stockDone = 0;
      onProgress?.call(0, stockUpdates.length, 'Actualizando stock');
      for (final product in stockUpdates) {
        final newStock = stockTargetById[product.id]!;
        final before = serverStocks.containsKey(product.id)
            ? serverStocks[product.id]
            : null;

        try {
          final next = await _supabaseCatalog.setStock(
            product.id,
            newStock,
            motivo: before == null || before == 0
                ? StockMotivo.carga
                : StockMotivo.ajuste,
            nota: 'Importación Excel',
            label: _productStockLabel(product),
          );
          final index = _products.indexWhere((item) => item.id == product.id);
          if (index != -1) {
            _products[index] = _products[index].copyWith(stock: next);
          }
        } catch (error, stackTrace) {
          AppLogger.error(
            'Import Excel: stock no registrado para ${product.id}',
            error: error,
            stackTrace: stackTrace,
          );
          rethrow;
        }
        stockDone++;
        onProgress?.call(stockDone, stockUpdates.length, 'Actualizando stock');
      }
      await _persistCache();
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
      fixedPrices: row.fixedPrices,
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

  /// Match para reimportar Excel.
  ///
  /// Prioridad: mismo tipo + mismo **código** (aunque cambie la marca detectada
  /// en el título del Excel). Así un reimport actualiza stock y no duplica.
  /// Fallback: marca + modelo/descripcion (planillas sin código).
  Product? _findMatchingRow(ExcelProductRow row) {
    final rowCodigo = row.codigo.trim().toLowerCase();
    if (rowCodigo.isNotEmpty) {
      for (final product in _products) {
        if (product.type != row.type) continue;
        if (product.codigo.trim().toLowerCase() == rowCodigo) {
          return product;
        }
      }
    }

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
        // Munición sin código: modelo o descripción.
        final rowKey = row.modelo.isNotEmpty ? row.modelo : row.descripcion;
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

  /// Pushes ficha to Supabase. Returns persisted id (may restore soft-delete).
  Future<String?> _pushToSupabase(Product product) async {
    if (!SupabaseService.isConfigured) return null;

    try {
      await _ensureSupabaseWriteContext();
      final persistedId = await _supabaseCatalog.upsert(product);
      if (persistedId != product.id) {
        // AR-35 safety net: upsert restored a soft-deleted row.
        final index = _products.indexWhere((item) => item.id == product.id);
        if (index != -1) {
          _products[index] = _products[index].copyWith(id: persistedId);
        }
      }
      return persistedId;
    } catch (error) {
      _lastError = error.toString();
      AppLogger.error('No se pudo guardar producto en Supabase', error: error);
      rethrow;
    }
  }

  /// Ajusta solo la cache local tras un descuento server-side (register_sale).
  Future<void> applyLocalSaleStockDecrement(Map<String, int> quantities) async {
    if (quantities.isEmpty) return;
    var changed = false;
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      final product = productById(entry.key);
      if (product?.stock == null) continue;
      _setLocalStock(entry.key, product!.stock! - entry.value);
      changed = true;
    }
    if (changed) {
      await _persistCache();
      notifyListeners();
    }
  }

  /// Ajusta solo la cache local tras una restitución server-side (void_sale).
  Future<void> applyLocalSaleStockRestore(Map<String, int> quantities) async {
    if (quantities.isEmpty) return;
    var changed = false;
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      final product = productById(entry.key);
      if (product?.stock == null) continue;
      _setLocalStock(entry.key, product!.stock! + entry.value);
      changed = true;
    }
    if (changed) {
      await _persistCache();
      notifyListeners();
    }
  }

  /// Descuenta stock tras una venta confirmada (Supabase primero, luego cache local).
  Future<void> applySaleStockDecrement(
    Map<String, int> quantities, {
    String? saleId,
    String? sellerId,
  }) async {
    if (quantities.isEmpty) return;

    final validationError = validateSaleQuantities(quantities);
    if (validationError != null) {
      throw StateError(validationError);
    }

    var changed = false;
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;

      final product = productById(entry.key);
      if (product == null) continue;

      final label = _productStockLabel(product);

      if (SupabaseService.isConfigured) {
        final next = await _supabaseCatalog.decrementStock(
          entry.key,
          entry.value,
          ventaId: saleId,
          vendedorId: sellerId,
          label: label,
        );
        _setLocalStock(entry.key, next);
        changed = true;
      } else {
        final current = product.stock!;
        _setLocalStock(entry.key, current - entry.value);
        changed = true;
      }
    }

    if (changed) {
      await _persistCache();
      notifyListeners();
    }
  }

  /// Restituye stock al anular una venta (Supabase primero, luego cache local).
  Future<void> applySaleStockRestore(
    Map<String, int> quantities, {
    String? saleId,
    String? sellerId,
  }) async {
    if (quantities.isEmpty) return;

    var changed = false;
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;

      final product = productById(entry.key);
      final label =
          product != null ? _productStockLabel(product) : entry.key;

      if (SupabaseService.isConfigured) {
        final next = await _supabaseCatalog.restoreStock(
          entry.key,
          entry.value,
          ventaId: saleId,
          vendedorId: sellerId,
          label: label,
        );
        _setLocalStock(entry.key, next);
        changed = true;
      } else if (product != null && product.stock != null) {
        _setLocalStock(entry.key, product.stock! + entry.value);
        changed = true;
      }
    }

    if (changed) {
      await _persistCache();
      notifyListeners();
    }
  }

  final SupabaseCatalogRepository _supabaseCatalog = SupabaseCatalogRepository();
  final ProductPhotoService _productPhotos = ProductPhotoService();

  List<Product> byType(ProductType type) {
    return _products.where((product) => product.type == type).toList();
  }

  List<String> brandsFor(ProductType type) {
    final byKey = <String, String>{};
    for (final product in byType(type)) {
      final raw = product.marca.trim();
      if (raw.isEmpty) continue;
      final key = marcaKey(raw);
      final existing = byKey[key];
      byKey[key] =
          existing == null ? raw : preferMarcaLabel(existing, raw);
    }
    final brands = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
        : byType(type).where((product) => sameMarca(product.marca, marca));
    final byKey = <String, String>{};
    var hasEmpty = false;
    for (final product in source) {
      final raw = product.calibre.trim();
      if (raw.isEmpty) {
        hasEmpty = true;
        continue;
      }
      final key = calibreKey(raw);
      if (key.isEmpty) {
        hasEmpty = true;
        continue;
      }
      final existing = byKey[key];
      byKey[key] =
          existing == null ? raw : preferCalibreLabel(existing, raw);
    }
    final calibers = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (hasEmpty) calibers.add(kCalibreSinEtiqueta);
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
    String? codigoQuery,
  }) {
    final query = codigoQuery?.trim() ?? '';
    final results = byType(type).where((product) {
      // Catálogo de venta: sin stock (null o 0) no se lista.
      if ((product.stock ?? 0) <= 0) return false;
      final marcaOk = marca == null || sameMarca(product.marca, marca);
      final calibreOk = calibre == null || sameCalibre(product.calibre, calibre);
      final marcaLetterOk = marcaLetter == null ||
          product.marca.toUpperCase().startsWith(marcaLetter.toUpperCase());
      final codigoOk = query.isEmpty ||
          (product.codigo.isNotEmpty &&
              product.codigo.toUpperCase().contains(query.toUpperCase()));
      return marcaOk && calibreOk && marcaLetterOk && codigoOk;
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

    final tenantId = _tenantScope?.trim();
    _realtimeChannel?.unsubscribe();
    var channel = SupabaseService.client.channel(
      'productos:${tenantId ?? 'all'}',
    );
    channel = channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'productos',
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
    );
    _realtimeChannel = channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('CatalogService realtime status=$status error=$error');
        unawaited(syncFromCloud(silent: true));
      }
    });
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
  void notifyListeners() {
    // Cualquier cambio del catálogo invalida los índices de búsqueda; se
    // reconstruyen perezosamente en la próxima búsqueda.
    _searchIndexCache.clear();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
