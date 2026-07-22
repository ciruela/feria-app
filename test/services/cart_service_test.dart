import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_product.dart';

void main() {
  late CartService cart;

  setUp(() {
    cart = CartService();
  });

  test('adds and merges products by id', () {
    final product = testProduct(id: 'p1', precioUsd: 100);

    expect(cart.addProduct(product), CartAddResult.added);
    expect(cart.addProduct(product), CartAddResult.added);
    expect(cart.items, hasLength(1));
    expect(cart.items.first.quantity, 2);
  });

  test('clears checkout payment when cart is cleared', () {
    cart.addProduct(testProduct());
    cart.setCheckoutPayment(
      const CartCheckoutPayment.single(PaymentMethod.transferencia),
    );

    cart.clear();

    expect(cart.isEmpty, isTrue);
    expect(cart.hasCheckoutPayment, isFalse);
  });
}
