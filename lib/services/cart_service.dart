import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
  });

  final Product product;
  int quantity;
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  void addProduct(Product product) {
    final existing =
        _items.where((item) => item.product.id == product.id).firstOrNull;

    if (existing != null) {
      existing.quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void removeProduct(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void changeQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final item =
        _items.where((element) => element.product.id == productId).firstOrNull;
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
