import 'package:flutter/foundation.dart';

import '../models/cart_checkout_payment.dart';
import '../config/app_config.dart';
import '../models/product.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.serialNumber = '',
    this.tarjetaConsumo = '',
  });

  final Product product;
  int quantity;
  String serialNumber;
  String tarjetaConsumo;

  String get lineKey => product.id;
}

enum CartAddResult {
  added,
  stockLimitReached,
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  CartCheckoutPayment? _checkoutPayment;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;
  CartCheckoutPayment? get checkoutPayment => _checkoutPayment;
  bool get hasCheckoutPayment => _checkoutPayment != null;

  List<CartItem> get weaponsMissingSerial => _items
      .where(
        (item) => item.product.isArma && item.serialNumber.trim().isEmpty,
      )
      .toList();

  void setCheckoutPayment(CartCheckoutPayment payment) {
    _checkoutPayment = payment;
    notifyListeners();
  }

  void clearCheckoutPayment() {
    if (_checkoutPayment == null) return;
    _checkoutPayment = null;
    notifyListeners();
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

  bool canAddMore(Product product) {
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

  CartAddResult addProduct(Product product) =>
      addProductQuantity(product, 1);

  CartAddResult addProductQuantity(Product product, int quantity) {
    if (quantity <= 0) return CartAddResult.stockLimitReached;
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

    final existing =
        _items.where((item) => item.product.id == product.id).firstOrNull;

    if (existing != null) {
      final max = maxQuantityForLine(existing);
      final newQuantity = existing.quantity + quantity;
      if (max != null && newQuantity > max) {
        return CartAddResult.stockLimitReached;
      }
      existing.quantity = newQuantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
    return CartAddResult.added;
  }

  void removeLine(String lineKey) {
    _items.removeWhere((element) => element.lineKey == lineKey);
    notifyListeners();
  }

  void changeQuantity(String lineKey, int quantity) {
    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    if (quantity <= 0) {
      removeLine(lineKey);
      return;
    }

    final max = maxQuantityForLine(item);
    if (max != null && quantity > max) {
      quantity = max;
    }

    item.quantity = quantity;
    notifyListeners();
  }

  void updateSerialNumber(String lineKey, String serialNumber) {
    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    item.serialNumber = serialNumber.trim();
    notifyListeners();
  }

  void updateTarjetaConsumo(String lineKey, String tarjetaConsumo) {
    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;

    item.tarjetaConsumo = tarjetaConsumo.trim();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _checkoutPayment = null;
    notifyListeners();
  }
}
