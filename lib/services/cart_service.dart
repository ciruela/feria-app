import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget.dart';
import '../models/cart_checkout_payment.dart';
import '../config/app_config.dart';
import '../models/product.dart';
import '../models/product_prices.dart';
import '../utils/ids.dart';
import '../utils/tenant_cache.dart';
import 'catalog_service.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.serialNumber = '',
    this.tarjetaConsumo = '',
    String? lineId,
  }) : lineId = lineId ?? newId('line');

  Product product;
  final String lineId;
  int quantity;
  String serialNumber;
  String tarjetaConsumo;

  String get lineKey => lineId;

  Map<String, dynamic> toJson() => {
        'lineId': lineId,
        'quantity': quantity,
        'serialNumber': serialNumber,
        'tarjetaConsumo': tarjetaConsumo,
        'product': product.toJson(),
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      lineId: json['lineId'] as String? ?? newId('line'),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      serialNumber: json['serialNumber'] as String? ?? '',
      tarjetaConsumo: json['tarjetaConsumo'] as String? ?? '',
      product: Product.fromJson(
        (json['product'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

enum CartAddResult {
  added,
  stockLimitReached,
  missingPrice,
}

class CartService extends ChangeNotifier {
  static const _cacheKeyBase = 'cart_cache_json_v1';

  final List<CartItem> _items = [];
  CartCheckoutPayment? _checkoutPayment;
  BudgetCustomer? _customerDraft;
  String? _saleIdempotencyKey;
  String? _tenantScope;
  String? _sellerScope;
  bool _restoring = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;
  CartCheckoutPayment? get checkoutPayment => _checkoutPayment;
  bool get hasCheckoutPayment => _checkoutPayment != null;
  String? get sellerScope => _sellerScope;

  /// Datos del cliente tipeados/escaneados en el presupuesto. Se conservan al
  /// volver al carrito para sumar un producto olvidado (AR: no perder el DNI).
  BudgetCustomer? get customerDraft => _customerDraft;

  /// Guarda el borrador del cliente sin notificar por defecto: los campos viven
  /// dentro del preview A4 (FittedBox) y un rebuild por tecla roba el foco.
  void setCustomerDraft(BudgetCustomer? customer, {bool notify = false}) {
    final next = (customer == null || customer.isEmpty) ? null : customer;
    _customerDraft = next;
    _schedulePersist();
    if (notify) notifyListeners();
  }

  /// Clave por armería + vendedor (AR-54). Sin vendedor = solo tenant.
  String get _cacheKey {
    final tenantKey = tenantCacheKey(_cacheKeyBase, _tenantScope);
    final seller = _sellerScope?.trim();
    if (seller == null || seller.isEmpty) return tenantKey;
    return '${tenantKey}_s_$seller';
  }

  /// Aísla el carrito por armería. Llamar al elegir tenant; luego [load].
  void bindTenant(String? tenantId) {
    final next = tenantId?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_tenantScope == normalized) return;
    _tenantScope = normalized;
    _sellerScope = null;
    _items.clear();
    _checkoutPayment = null;
    _customerDraft = null;
    _saleIdempotencyKey = null;
    notifyListeners();
  }

  /// Aísla el carrito por vendedor dentro del tenant (AR-54). Luego [load].
  void bindSeller(String? sellerId) {
    final next = sellerId?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (_sellerScope == normalized) return;
    _sellerScope = normalized;
    _items.clear();
    _checkoutPayment = null;
    _customerDraft = null;
    _saleIdempotencyKey = null;
    notifyListeners();
  }

  /// Restaura el carrito desde SharedPreferences (AR-47).
  Future<void> load({CatalogService? catalog}) async {
    await _loadFromCache(catalog: catalog);
    if (_splitMergedWeapons()) {
      await _persistCache();
    }
    notifyListeners();
  }

  /// AR-41: garantiza una línea qty=1 por arma (presupuesto / series).
  void ensureWeaponsAreUnitLines() {
    if (_splitMergedWeapons()) {
      _notifyAndPersist();
    }
  }

  /// AR-41: cada arma es una línea qty=1. Repara caches viejos o qty>1.
  bool _splitMergedWeapons() {
    final needsSplit = _items.any((item) => item.product.isArma && item.quantity > 1);
    if (!needsSplit) return false;

    final next = <CartItem>[];
    for (final item in _items) {
      if (!item.product.isArma || item.quantity <= 1) {
        next.add(item);
        continue;
      }
      for (var i = 0; i < item.quantity; i++) {
        next.add(
          CartItem(
            product: item.product,
            quantity: 1,
            // Solo la primera conserva la serie ya tipada.
            serialNumber: i == 0 ? item.serialNumber : '',
            tarjetaConsumo: i == 0 ? item.tarjetaConsumo : '',
            lineId: i == 0 ? item.lineId : null,
          ),
        );
      }
    }
    _items
      ..clear()
      ..addAll(next);
    return true;
  }

  /// Stable for the whole checkout attempt so retries reuse the same sale key.
  String ensureSaleIdempotencyKey() => _saleIdempotencyKey ??= newId('sale');

  /// Replaces cart products whose `precioUsd` changed in [catalog].
  /// Returns true if any line was updated.
  bool refreshProducts(CatalogService catalog) {
    var changed = false;
    for (final item in _items) {
      final fresh = catalog.productById(item.product.id);
      if (fresh != null && fresh.precioUsd != item.product.precioUsd) {
        item.product = fresh;
        changed = true;
      }
    }
    if (changed) {
      _notifyAndPersist();
    }
    return changed;
  }

  List<CartItem> get weaponsMissingSerial => _items
      .where(
        (item) => item.product.isArma && item.serialNumber.trim().isEmpty,
      )
      .toList();

  void setCheckoutPayment(CartCheckoutPayment payment) {
    _checkoutPayment = payment;
    _notifyAndPersist();
  }

  void clearCheckoutPayment() {
    if (_checkoutPayment == null) return;
    _checkoutPayment = null;
    _notifyAndPersist();
  }

  int quantityInCart(String productId) {
    return _items
        .where((item) => item.product.id == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  int? remainingStock(Product product) {
    final stock = product.stock;
    if (stock == null) return null;

    return (stock - quantityInCart(product.id)).clamp(0, stock);
  }

  /// Un producto se puede vender si tiene precio USD > 0 o precios fijos del
  /// Excel (Urban Tactical, que cotiza en ARS y puede tener USD 0).
  bool _hasSellablePrice(Product product) =>
      product.precioUsd > 0 || product.hasFixedPrices;

  bool canAddMore(Product product) {
    if (!_hasSellablePrice(product)) return false;
    if (AppConfig.useSupabase && product.stock == null) return false;
    if (!product.inStock) return false;

    final remaining = remainingStock(product);
    return remaining == null || remaining > 0;
  }

  int? maxQuantityForLine(CartItem item) {
    final stock = item.product.stock;
    if (stock == null) return null;

    final othersInCart = quantityInCart(item.product.id) - item.quantity;
    return (stock - othersInCart).clamp(0, stock);
  }

  CartAddResult addProduct(Product product) => addProductQuantity(product, 1);

  CartAddResult addProductQuantity(Product product, int quantity) {
    if (quantity <= 0) return CartAddResult.stockLimitReached;
    if (!_hasSellablePrice(product)) {
      return CartAddResult.missingPrice;
    }
    if (AppConfig.useSupabase && product.stock == null) {
      return CartAddResult.stockLimitReached;
    }
    if (!product.inStock) {
      return CartAddResult.stockLimitReached;
    }

    final remaining = remainingStock(product);
    if (remaining != null && quantity > remaining) {
      return CartAddResult.stockLimitReached;
    }

    if (product.isArma) {
      // One weapon = one line = one serial number.
      for (var i = 0; i < quantity; i++) {
        _items.add(CartItem(product: product, quantity: 1));
      }
      _notifyAndPersist();
      return CartAddResult.added;
    }

    final existing = _items
        .where((item) => !item.product.isArma && item.product.id == product.id)
        .firstOrNull;

    if (existing != null) {
      final max = maxQuantityForLine(existing);
      final newQuantity = existing.quantity + quantity;
      if (max != null && newQuantity > max) {
        return CartAddResult.stockLimitReached;
      }
      existing.quantity = newQuantity;
    } else {
      // Munición nueva de un calibre que ya tiene TC cargada: hereda esa TC
      // (una sola tarjeta de consumo por calibre).
      _items.add(CartItem(
        product: product,
        quantity: quantity,
        tarjetaConsumo: _tarjetaConsumoForCaliber(product),
      ));
    }
    _notifyAndPersist();
    return CartAddResult.added;
  }

  void removeLine(String lineKey) {
    _items.removeWhere((element) => element.lineKey == lineKey);
    _notifyAndPersist();
  }

  void changeQuantity(String lineKey, int quantity) {
    final item =
        _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    if (quantity <= 0) {
      removeLine(lineKey);
      return;
    }

    // AR-41: armas nunca acumulan qty; cada unidad es una línea con su serie.
    if (item.product.isArma) {
      if (quantity == 1) {
        if (item.quantity != 1) {
          item.quantity = 1;
          _notifyAndPersist();
        }
        return;
      }
      final extra = quantity - 1;
      item.quantity = 1;
      for (var i = 0; i < extra; i++) {
        if (!canAddMore(item.product)) break;
        _items.add(CartItem(product: item.product, quantity: 1));
      }
      _notifyAndPersist();
      return;
    }

    final max = maxQuantityForLine(item);
    if (max != null && quantity > max) {
      quantity = max;
    }

    item.quantity = quantity;
    _notifyAndPersist();
  }

  /// Actualiza el N° de serie. Por defecto no notifica: el campo vive dentro
  /// del preview A4 (FittedBox) y un rebuild por tecla pierde el foco / rompe
  /// la edición. El valor queda en el carrito para PDF y finalize.
  void updateSerialNumber(
    String lineKey,
    String serialNumber, {
    bool notify = false,
  }) {
    final item =
        _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    item.serialNumber = serialNumber.trim();
    _schedulePersist();
    if (notify) notifyListeners();
  }

  void updateTarjetaConsumo(String lineKey, String tarjetaConsumo) {
    final item =
        _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    final value = tarjetaConsumo.trim();
    item.tarjetaConsumo = value;

    // La tarjeta de consumo es por calibre: replicar en todas las líneas de
    // munición del mismo calibre para que compartan una sola TC.
    if (item.product.isMunicion) {
      final cal = _calibreKey(item.product);
      if (cal.isNotEmpty) {
        for (final other in _items) {
          if (other.lineKey == lineKey) continue;
          if (other.product.isMunicion && _calibreKey(other.product) == cal) {
            other.tarjetaConsumo = value;
          }
        }
      }
    }

    _notifyAndPersist();
  }

  /// Clave normalizada de calibre para agrupar tarjetas de consumo de munición.
  String _calibreKey(Product product) => product.calibre.trim().toLowerCase();

  /// TC ya cargada para el calibre de [product] (munición), si existe.
  String _tarjetaConsumoForCaliber(Product product) {
    if (!product.isMunicion) return '';
    final cal = _calibreKey(product);
    if (cal.isEmpty) return '';
    for (final item in _items) {
      if (item.product.isMunicion &&
          _calibreKey(item.product) == cal &&
          item.tarjetaConsumo.trim().isNotEmpty) {
        return item.tarjetaConsumo.trim();
      }
    }
    return '';
  }

  void clear() {
    _items.clear();
    _checkoutPayment = null;
    _customerDraft = null;
    _saleIdempotencyKey = null;
    _notifyAndPersist();
  }

  void _notifyAndPersist() {
    notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    if (_restoring) return;
    unawaited(_persistCache());
  }

  Future<void> _loadFromCache({CatalogService? catalog}) async {
    _restoring = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) {
        _items.clear();
        _checkoutPayment = null;
        _customerDraft = null;
        _saleIdempotencyKey = null;
        return;
      }

      final data = json.decode(raw) as Map<String, dynamic>;
      final itemsRaw = data['items'];
      final restored = <CartItem>[];
      if (itemsRaw is List) {
        for (final entry in itemsRaw) {
          if (entry is! Map) continue;
          try {
            final item = CartItem.fromJson(entry.cast<String, dynamic>());
            final fresh = catalog?.productById(item.product.id);
            if (fresh != null) {
              item.product = fresh;
            }
            restored.add(item);
          } catch (_) {
            // Skip corrupt lines.
          }
        }
      }

      _items
        ..clear()
        ..addAll(restored);
      _checkoutPayment = _checkoutFromJson(data['checkout']);
      _customerDraft = _customerDraftFromJson(data['customer']);
      _saleIdempotencyKey = data['saleIdempotencyKey'] as String?;
    } catch (_) {
      _items.clear();
      _checkoutPayment = null;
      _customerDraft = null;
      _saleIdempotencyKey = null;
    } finally {
      _restoring = false;
    }
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_items.isEmpty && _checkoutPayment == null && _customerDraft == null) {
      await prefs.remove(_cacheKey);
      return;
    }

    final payload = <String, dynamic>{
      'items': _items.map((item) => item.toJson()).toList(),
      if (_checkoutPayment != null) 'checkout': _checkoutToJson(_checkoutPayment!),
      if (_customerDraft != null) 'customer': _customerDraft!.toJson(),
      if (_saleIdempotencyKey != null)
        'saleIdempotencyKey': _saleIdempotencyKey,
    };
    await prefs.setString(_cacheKey, json.encode(payload));
  }

  Map<String, dynamic> _checkoutToJson(CartCheckoutPayment payment) => {
        'pricingMethod': payment.pricingMethod.key,
        if (payment.secondMethod != null)
          'secondMethod': payment.secondMethod!.key,
        'primaryShare': payment.primaryShare,
      };

  BudgetCustomer? _customerDraftFromJson(Object? raw) {
    if (raw is! Map) return null;
    final customer = BudgetCustomer.fromJson(raw.cast<String, dynamic>());
    return customer.isEmpty ? null : customer;
  }

  CartCheckoutPayment? _checkoutFromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final primaryKey = map['pricingMethod'] as String?;
    if (primaryKey == null || primaryKey.isEmpty) return null;
    final primary = PaymentMethod.fromKey(primaryKey);
    final secondKey = map['secondMethod'] as String?;
    final share = (map['primaryShare'] as num?)?.toDouble() ?? 1.0;
    if (secondKey == null || secondKey.isEmpty) {
      return CartCheckoutPayment.single(primary);
    }
    return CartCheckoutPayment.dual(
      pricingMethod: primary,
      secondMethod: PaymentMethod.fromKey(secondKey),
      primaryShare: share,
    );
  }
}
