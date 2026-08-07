import 'package:app_feria/models/product.dart';
import 'package:app_feria/utils/product_id_remap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_product.dart';

void main() {
  test('remaps product ids and stock maps after soft-delete restore', () {
    final products = <Product>[
      testProduct(id: 'temp-new', codigo: 'C-1'),
      testProduct(id: 'other', codigo: 'C-2'),
    ];
    final changed = <Product>[products.first];
    final stockTarget = <String, int?>{'temp-new': 5};
    final serverStocks = <String, int?>{'temp-new': 2};

    applyProductIdRemaps(
      {'temp-new': 'original-soft-deleted'},
      products: products,
      changedProducts: changed,
      stockTargetById: stockTarget,
      serverStocks: serverStocks,
    );

    expect(products.first.id, 'original-soft-deleted');
    expect(changed.single.id, 'original-soft-deleted');
    expect(stockTarget, {'original-soft-deleted': 5});
    expect(serverStocks, {'original-soft-deleted': 2});
    expect(products[1].id, 'other');
  });

  test('no-op when remap map is empty', () {
    final products = <Product>[testProduct(id: 'a')];
    applyProductIdRemaps(const {}, products: products);
    expect(products.single.id, 'a');
  });
}
