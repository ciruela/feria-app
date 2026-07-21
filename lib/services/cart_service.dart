import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_prices.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.paymentMethod = PaymentMethod.lista,
  });

  final Product product;
  int quantity;
  PaymentMethod paymentMethod;

  String get lineKey => '${product.id}_${paymentMethod.key}';
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  void addProduct(
    Product product, {
    PaymentMethod paymentMethod = PaymentMethod.lista,
  }) {
    final existing = _items
        .where((item) => item.lineKey == '${product.id}_${paymentMethod.key}')
        .firstOrNull;

    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(
        CartItem(
          product: product,
          paymentMethod: paymentMethod,
        ),
      );
    }
    notifyListeners();
  }

  void updatePaymentMethod(String lineKey, PaymentMethod paymentMethod) {
    final index = _items.indexWhere((item) => item.lineKey == lineKey);
    if (index == -1) return;

    final item = _items[index];
    final updated = CartItem(
      product: item.product,
      quantity: item.quantity,
      paymentMethod: paymentMethod,
    );

    final duplicate = _items
        .where(
          (element) =>
              element.lineKey == updated.lineKey && element.lineKey != lineKey,
        )
        .firstOrNull;

    if (duplicate != null) {
      duplicate.quantity += updated.quantity;
      _items.removeAt(index);
    } else {
      _items[index] = updated;
    }
    notifyListeners();
  }

  void removeLine(String lineKey) {
    _items.removeWhere((item) => item.lineKey == lineKey);
    notifyListeners();
  }

  void changeQuantity(String lineKey, int quantity) {
    if (quantity <= 0) {
      removeLine(lineKey);
      return;
    }

    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item != null) {
      item.quantity = quantity;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
