import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_product.dart';

void main() {
  late CartService cart;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cart = CartService();
  });

  test('adds and merges munition by product id', () {
    final product = testProduct(id: 'p1', precioUsd: 100);

    expect(cart.addProduct(product), CartAddResult.added);
    expect(cart.addProduct(product), CartAddResult.added);
    expect(cart.items, hasLength(1));
    expect(cart.items.first.quantity, 2);
  });

  test('adds weapons as separate lines of quantity 1', () {
    final weapon = testProduct(
      id: 'arma1',
      precioUsd: 500,
      type: ProductType.armaCorta,
      stock: 5,
    );

    expect(cart.addProductQuantity(weapon, 2), CartAddResult.added);
    expect(cart.items, hasLength(2));
    expect(cart.items.every((item) => item.quantity == 1), isTrue);
    expect(cart.items[0].lineKey, isNot(cart.items[1].lineKey));
    expect(cart.quantityInCart('arma1'), 2);
    expect(cart.weaponsMissingSerial, hasLength(2));
  });

  test('changeQuantity on weapon splits into lines (AR-41)', () {
    final weapon = testProduct(
      id: 'arma1',
      precioUsd: 500,
      type: ProductType.armaCorta,
      stock: 5,
    );
    expect(cart.addProduct(weapon), CartAddResult.added);
    cart.changeQuantity(cart.items.single.lineKey, 3);

    expect(cart.items, hasLength(3));
    expect(cart.items.every((item) => item.quantity == 1), isTrue);
    expect(cart.weaponsMissingSerial, hasLength(3));
  });

  test('addProductQuantity respects stock limit', () {
    final product = testProduct(id: 'p1', stock: 3);

    expect(cart.addProductQuantity(product, 2), CartAddResult.added);
    expect(cart.items.first.quantity, 2);
    expect(cart.addProductQuantity(product, 2), CartAddResult.stockLimitReached);
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

  test('sale idempotency key is stable until cart clear', () {
    final first = cart.ensureSaleIdempotencyKey();
    final second = cart.ensureSaleIdempotencyKey();
    expect(second, first);

    cart.clear();
    final afterClear = cart.ensureSaleIdempotencyKey();
    expect(afterClear, isNot(first));
  });

  test('refreshProducts updates stale prices from catalog', () async {
    final catalog = CatalogService();
    await catalog.addProduct(
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '.22 LR',
      codigo: 'R32',
      precioUsd: 100,
      stock: 5,
      roundsPerBox: 50,
    );
    final original = catalog.products.single;
    expect(cart.addProduct(original), CartAddResult.added);

    await catalog.updateProduct(original.copyWith(precioUsd: 150));
    expect(cart.items.single.product.precioUsd, 100);

    expect(cart.refreshProducts(catalog), isTrue);
    expect(cart.items.single.product.precioUsd, 150);
    expect(cart.refreshProducts(catalog), isFalse);
  });

  test('persists cart across reload (AR-47)', () async {
    final product = testProduct(id: 'persist-1', precioUsd: 40, stock: 4);
    expect(cart.addProductQuantity(product, 2), CartAddResult.added);
    cart.updateSerialNumber(cart.items.single.lineKey, 'SN-9');
    // Allow async SharedPreferences write.
    await Future<void>.delayed(Duration.zero);

    final restored = CartService();
    await restored.load();
    expect(restored.items, hasLength(1));
    expect(restored.items.single.quantity, 2);
    expect(restored.items.single.product.id, 'persist-1');
    expect(restored.items.single.serialNumber, 'SN-9');
  });

  test('clear removes persisted cart', () async {
    cart.addProduct(testProduct(id: 'x'));
    await Future<void>.delayed(Duration.zero);
    cart.clear();
    await Future<void>.delayed(Duration.zero);

    final restored = CartService();
    await restored.load();
    expect(restored.isEmpty, isTrue);
  });

  test('cart is isolated per seller within tenant (AR-54)', () async {
    cart.bindTenant('tenant-a');
    cart.bindSeller('seller-1');
    expect(cart.addProduct(testProduct(id: 'p-s1')), CartAddResult.added);
    await Future<void>.delayed(Duration.zero);

    cart.bindSeller('seller-2');
    expect(cart.isEmpty, isTrue);
    expect(cart.addProduct(testProduct(id: 'p-s2')), CartAddResult.added);
    await Future<void>.delayed(Duration.zero);

    final seller1 = CartService()
      ..bindTenant('tenant-a')
      ..bindSeller('seller-1');
    await seller1.load();
    expect(seller1.items.single.product.id, 'p-s1');

    final seller2 = CartService()
      ..bindTenant('tenant-a')
      ..bindSeller('seller-2');
    await seller2.load();
    expect(seller2.items.single.product.id, 'p-s2');
  });
}
