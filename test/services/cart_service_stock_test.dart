import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';

Product _prod({int? stock}) => Product(
      id: 'municion_1',
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '22',
      codigo: 'C-1',
      precioUsd: 10,
      stock: stock,
    );

void main() {
  test('Urban: producto con USD 0 pero precios fijos se puede agregar', () {
    final cart = CartService();
    const p = Product(
      id: 'bersa_1',
      type: ProductType.armaCorta,
      marca: 'BERSA',
      calibre: '9',
      codigo: '0T9',
      precioUsd: 0, // Urban cotiza en ARS: USD 0 no debe bloquear la venta.
      stock: 5,
      fixedPrices: FixedPrices(efectivoArs: 500000, tarjetaArs: 520000),
    );
    expect(cart.canAddMore(p), isTrue);
    expect(cart.addProduct(p), CartAddResult.added);
    expect(cart.itemCount, 1);
  });

  test('producto con USD 0 y sin precios fijos sigue bloqueado', () {
    final cart = CartService();
    const p = Product(
      id: 'sinprecio_1',
      type: ProductType.municion,
      marca: 'X',
      calibre: '9',
      codigo: 'NP',
      precioUsd: 0,
      stock: 5,
    );
    expect(cart.canAddMore(p), isFalse);
    expect(cart.addProduct(p), CartAddResult.missingPrice);
  });

  test('respeta el límite de stock', () {
    final cart = CartService();
    final p = _prod(stock: 2);
    expect(cart.addProduct(p), CartAddResult.added);
    expect(cart.addProduct(p), CartAddResult.added);
    expect(cart.addProduct(p), CartAddResult.stockLimitReached);
    expect(cart.itemCount, 2);
    expect(cart.canAddMore(p), isFalse);
  });

  test('remainingStock descuenta lo que hay en el carrito', () {
    final cart = CartService();
    final p = _prod(stock: 5);
    cart.addProduct(p);
    expect(cart.remainingStock(p), 4);
    expect(cart.quantityInCart('municion_1'), 1);
  });

  test('stock null = sin límite', () {
    final cart = CartService();
    final p = _prod();
    expect(cart.remainingStock(p), isNull);
    expect(cart.canAddMore(p), isTrue);
  });

  test('producto sin stock no se puede agregar', () {
    final cart = CartService();
    expect(cart.addProduct(_prod(stock: 0)), CartAddResult.stockLimitReached);
  });

  test('changeQuantity recorta al máximo y elimina en 0', () {
    final cart = CartService();
    final p = _prod(stock: 3);
    cart.addProduct(p);
    final lineKey = cart.items.single.lineKey;
    cart.changeQuantity(lineKey, 10);
    expect(cart.quantityInCart('municion_1'), 3); // recorta a stock

    cart.changeQuantity(lineKey, 0);
    expect(cart.isEmpty, isTrue);
  });

  test('updateSerialNumber y weaponsMissingSerial', () {
    const arma = Product(
      id: 'arma_corta_1',
      type: ProductType.armaCorta,
      marca: 'Glock',
      calibre: '9',
      codigo: 'G17',
      precioUsd: 500,
    );
    final cart = CartService()..addProduct(arma);
    expect(cart.weaponsMissingSerial.length, 1);

    cart.updateSerialNumber(cart.items.single.lineKey, '  ABC123 ');
    expect(cart.weaponsMissingSerial, isEmpty);
    expect(cart.items.single.serialNumber, 'ABC123');
  });

  test('removeLine elimina la línea', () {
    final cart = CartService();
    cart.addProduct(_prod(stock: 5));
    cart.removeLine(cart.items.single.lineKey);
    expect(cart.isEmpty, isTrue);
  });
}
