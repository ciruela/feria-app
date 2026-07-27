import 'package:app_feria/models/cart_checkout_payment.dart';
import 'package:app_feria/models/invoice.dart';
import 'package:app_feria/models/product.dart';
import 'package:app_feria/models/product_prices.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/invoice_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const municion = Product(
    id: 'municion_1',
    type: ProductType.municion,
    marca: 'CCI',
    calibre: '22',
    codigo: 'C-1',
    precioUsd: 100,
  );
  const arma = Product(
    id: 'arma_corta_1',
    type: ProductType.armaCorta,
    marca: 'Glock',
    calibre: '9',
    codigo: 'G17',
    modelo: 'G17 Gen5',
    precioUsd: 500,
  );

  test('ProductInvoiceX arma vs munición', () {
    expect(municion.invoiceProductName, 'CCI · C-1');
    expect(arma.invoiceProductName, 'Glock · G17 Gen5');
  });

  test('buildFromCart calcula líneas y totales', () {
    final cart = CartService()
      ..addProduct(municion)
      ..addProduct(municion) // qty 2
      ..addProduct(arma)
      ..setCheckoutPayment(
        const CartCheckoutPayment.single(PaymentMethod.lista),
      );

    final invoice = InvoiceService().buildFromCart(
      buyerFullName: '  Juan Perez  ',
      cart: cart,
      exchangeRate: ExchangeRateService(), // 1500
      pricingSettings: PricingSettingsService(),
    );

    expect(invoice.buyerFullName, 'Juan Perez');
    expect(invoice.lines.length, 2);

    final municionLine =
        invoice.lines.firstWhere((l) => l.internalCode == 'municion_1');
    expect(municionLine.quantity, 2);
    expect(municionLine.lineUsd, 200); // 100 * 2
    expect(municionLine.lineArs, 300000); // 100 * 1500 * 2
    expect(municionLine.paymentLabel, PaymentMethod.lista.label);

    expect(invoice.totalUsd, 700); // 200 + 500
    expect(invoice.totalArs, 1050000); // 300000 + 750000
  });

  test('usa el método por defecto si no hay checkout payment', () {
    final cart = CartService()..addProduct(municion);
    final invoice = InvoiceService().buildFromCart(
      buyerFullName: 'X',
      cart: cart,
      exchangeRate: ExchangeRateService(),
      pricingSettings: PricingSettingsService(),
    );
    expect(invoice.lines.single.lineUsd, 100);
  });
}
