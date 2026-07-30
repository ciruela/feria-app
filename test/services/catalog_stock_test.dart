import 'package:app_feria/models/product.dart';
import 'package:app_feria/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('applySaleStockDecrement updates local stock', () async {
    final catalog = CatalogService();
    await catalog.addProduct(
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '.22 LR',
      codigo: '0032',
      precioUsd: 10,
      stock: 5,
      roundsPerBox: 50,
    );

    final productId = catalog.products.single.id;

    await catalog.applySaleStockDecrement({productId: 2});

    expect(catalog.products.single.stock, 3);
  });

  test('applySaleStockDecrement rechaza stock insuficiente', () async {
    final catalog = CatalogService();
    await catalog.addProduct(
      type: ProductType.municion,
      marca: 'CCI',
      calibre: '.22 LR',
      codigo: '0033',
      precioUsd: 10,
      stock: 1,
      roundsPerBox: 50,
    );

    final productId = catalog.products.single.id;

    expect(
      () => catalog.applySaleStockDecrement({productId: 3}),
      throwsA(isA<StateError>()),
    );
    expect(catalog.products.single.stock, 1);
  });
}
