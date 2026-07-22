import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_prices.dart';
import '../models/weapon_payment_selection.dart';

class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.paymentMethod = PaymentMethod.transferencia,
    this.serialNumber = '',
    this.paymentShare = 1.0,
    this.splitGroupId,
    this.splitPart,
  });

  final Product product;
  int quantity;
  PaymentMethod paymentMethod;
  String serialNumber;
  final double paymentShare;
  final String? splitGroupId;
  final int? splitPart;

  bool get isSplitPart => splitGroupId != null;

  String get lineKey => isSplitPart
      ? '${splitGroupId}_${paymentMethod.key}'
      : '${product.id}_${paymentMethod.key}';
}

enum CartAddResult {
  added,
  stockLimitReached,
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  int quantityInCart(String productId) {
    var total = 0;
    final countedSplitGroups = <String>{};

    for (final item in _items) {
      if (item.product.id != productId) continue;

      if (item.splitGroupId != null) {
        if (countedSplitGroups.add(item.splitGroupId!)) {
          total += 1;
        }
      } else {
        total += item.quantity;
      }
    }

    return total;
  }

  int? remainingStock(Product product) {
    final stock = product.stock;
    if (stock == null) return null;

    return (stock - quantityInCart(product.id)).clamp(0, stock);
  }

  bool canAddMore(Product product) {
    if (!product.inStock) return false;

    final remaining = remainingStock(product);
    return remaining == null || remaining > 0;
  }

  int? maxQuantityForLine(CartItem item) {
    final stock = item.product.stock;
    if (stock == null) return null;

    final currentLineQty = item.isSplitPart ? 1 : item.quantity;
    final othersInCart = quantityInCart(item.product.id) - currentLineQty;
    return (stock - othersInCart).clamp(0, stock);
  }

  CartAddResult addProduct(
    Product product, {
    PaymentMethod paymentMethod = PaymentMethod.transferencia,
  }) {
    if (!canAddMore(product)) {
      return CartAddResult.stockLimitReached;
    }

    final existing = _items
        .where((item) => item.lineKey == '${product.id}_${paymentMethod.key}')
        .firstOrNull;

    if (existing != null) {
      final max = maxQuantityForLine(existing);
      if (max != null && existing.quantity >= max) {
        return CartAddResult.stockLimitReached;
      }
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
    return CartAddResult.added;
  }

  CartAddResult addWeaponPayment(
    Product product,
    WeaponPaymentSelection selection,
  ) {
    if (!canAddMore(product)) {
      return CartAddResult.stockLimitReached;
    }

    if (!selection.isDual) {
      return addProduct(product, paymentMethod: selection.first);
    }

    final splitGroupId =
        '${product.id}_split_${DateTime.now().millisecondsSinceEpoch}';

    _items.add(
      CartItem(
        product: product,
        paymentMethod: selection.first,
        paymentShare: selection.firstShare,
        splitGroupId: splitGroupId,
        splitPart: 1,
      ),
    );
    _items.add(
      CartItem(
        product: product,
        paymentMethod: selection.second!,
        paymentShare: selection.secondShare,
        splitGroupId: splitGroupId,
        splitPart: 2,
      ),
    );
    notifyListeners();
    return CartAddResult.added;
  }

  void updatePaymentMethod(String lineKey, PaymentMethod paymentMethod) {
    final index = _items.indexWhere((item) => item.lineKey == lineKey);
    if (index == -1) return;

    final item = _items[index];
    if (item.isSplitPart) return;

    final updated = CartItem(
      product: item.product,
      quantity: item.quantity,
      paymentMethod: paymentMethod,
      serialNumber: item.serialNumber,
    );

    final duplicate = _items
        .where(
          (element) =>
              element.lineKey == updated.lineKey && element.lineKey != lineKey,
        )
        .firstOrNull;

    if (duplicate != null) {
      final max = maxQuantityForLine(duplicate);
      var mergedQty = duplicate.quantity + updated.quantity;
      if (max != null && mergedQty > max) {
        mergedQty = max;
      }
      duplicate.quantity = mergedQty;
      _items.removeAt(index);
    } else {
      _items[index] = updated;
    }
    notifyListeners();
  }

  void removeLine(String lineKey) {
    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item?.isSplitPart ?? false) {
      _items.removeWhere((element) => element.splitGroupId == item!.splitGroupId);
    } else {
      _items.removeWhere((element) => element.lineKey == lineKey);
    }
    notifyListeners();
  }

  void changeQuantity(String lineKey, int quantity) {
    final item = _items.where((element) => element.lineKey == lineKey).firstOrNull;
    if (item == null) return;
    if (item.isSplitPart) return;

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

    final normalized = serialNumber.trim();
    if (item.isSplitPart) {
      for (final sibling in _items) {
        if (sibling.splitGroupId == item.splitGroupId) {
          sibling.serialNumber = normalized;
        }
      }
    } else {
      item.serialNumber = normalized;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
