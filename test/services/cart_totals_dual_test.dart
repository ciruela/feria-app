import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/cart_totals_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CartTotalsService.allocationsFor dual', () {
    final totals = CartTotalsService();
    const total = CartLineTotal(usd: 100, ars: 150000);

    test('USD + ARS: shares suman 1 y cada medio usa su moneda', () {
      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.dolarBillete,
        secondMethod: PaymentMethod.efectivo,
        primaryShare: 0.6,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);
      expect(allocs.length, 2);
      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
      expect(allocs[0].amountUsd, closeTo(60, 0.001));
      expect(allocs[0].amountArs, 0);
      expect(allocs[1].amountUsd, 0);
      expect(allocs[1].amountArs, closeTo(60000, 0.001));
    });

    test('ARS + ARS: ambos en pesos con shares', () {
      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.efectivo,
        secondMethod: PaymentMethod.transferencia,
        primaryShare: 0.4,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);
      expect(allocs[0].amountArs, closeTo(60000, 0.001));
      expect(allocs[1].amountArs, closeTo(90000, 0.001));
      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
    });
  });

  // Urban: precios fijos del Excel. El cobro doble USD+ARS debe repartir
  // exactamente efectivo_usd (pata USD) y efectivo_ars (pata ARS), sin cruzar
  // monedas por tipo de cambio.
  group('cobro doble Urban (precios fijos) es fiel al Excel', () {
    late CartTotalsService totals;
    late ExchangeRateService exchangeRate;
    late PricingSettingsService settings;
    late CartService cart;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      totals = CartTotalsService();
      exchangeRate = ExchangeRateService(); // rate por defecto: NO debe usarse
      settings = PricingSettingsService();
      cart = CartService();
    });

    Product urbanRifle() => const Product(
          id: 'urban-rifle',
          type: ProductType.armaLarga,
          marca: 'SIBIAN ARMORY',
          calibre: '.223',
          codigo: 'SIB223',
          precioUsd: 3500,
          stock: 5,
          fixedPrices: FixedPrices(
            efectivoArs: 5495000,
            efectivoUsd: 3500,
            tarjetaArs: 5659850,
          ),
        );

    test('USD (primaria) + efectivo ARS: montos exactos del Excel', () {
      cart.addProduct(urbanRifle());

      final total = totals.cartTotalAtMethod(
        cart: cart,
        method: PaymentMethod.dolarBillete,
        exchangeRate: exchangeRate,
        pricingSettings: settings,
      );
      // El total por moneda sale tal cual del Excel (sin tipo de cambio).
      expect(total.usd, 3500);
      expect(total.ars, 5495000);

      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.dolarBillete,
        secondMethod: PaymentMethod.efectivo,
        primaryShare: 0.6,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);

      expect(allocs[0].method, PaymentMethod.dolarBillete);
      expect(allocs[0].amountUsd, closeTo(3500 * 0.6, 0.0001));
      expect(allocs[0].amountArs, 0);

      expect(allocs[1].method, PaymentMethod.efectivo);
      expect(allocs[1].amountUsd, 0);
      expect(allocs[1].amountArs, closeTo(5495000 * 0.4, 0.001));

      expect(allocs[0].share + allocs[1].share, closeTo(1.0, 0.0001));
    });

    test('efectivo ARS (primaria) + USD: montos exactos del Excel', () {
      cart.addProduct(urbanRifle());

      final total = totals.cartTotalAtMethod(
        cart: cart,
        method: PaymentMethod.efectivo,
        exchangeRate: exchangeRate,
        pricingSettings: settings,
      );
      expect(total.ars, 5495000);
      expect(total.usd, 3500);

      const checkout = CartCheckoutPayment.dual(
        pricingMethod: PaymentMethod.efectivo,
        secondMethod: PaymentMethod.dolarBillete,
        primaryShare: 0.7,
      );
      final allocs = totals.allocationsFor(checkout: checkout, total: total);

      expect(allocs[0].method, PaymentMethod.efectivo);
      expect(allocs[0].amountArs, closeTo(5495000 * 0.7, 0.001));
      expect(allocs[0].amountUsd, 0);

      expect(allocs[1].method, PaymentMethod.dolarBillete);
      expect(allocs[1].amountUsd, closeTo(3500 * 0.3, 0.0001));
      expect(allocs[1].amountArs, 0);
    });
  });
}
