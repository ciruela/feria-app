import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_feria/main.dart';
import 'package:app_feria/services/auth_service.dart';
import 'package:app_feria/services/cart_service.dart';
import 'package:app_feria/services/catalog_service.dart';
import 'package:app_feria/services/exchange_rate_service.dart';
import 'package:app_feria/services/pricing_settings_service.dart';
import 'package:app_feria/services/seller_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads role gate screen', (WidgetTester tester) async {
    final catalogService = CatalogService();
    final exchangeRateService = ExchangeRateService();
    final authService = AuthService();
    final sellerService = SellerService();
    final cartService = CartService();
    final pricingSettingsService = PricingSettingsService();

    await catalogService.load();
    await exchangeRateService.load();
    await authService.load();
    await sellerService.load();
    await pricingSettingsService.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CatalogService>.value(value: catalogService),
          ChangeNotifierProvider<ExchangeRateService>.value(
            value: exchangeRateService,
          ),
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<SellerService>.value(value: sellerService),
          ChangeNotifierProvider<CartService>.value(value: cartService),
          ChangeNotifierProvider<PricingSettingsService>.value(
            value: pricingSettingsService,
          ),
        ],
        child: const FeriaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catálogo Feria'), findsOneWidget);
    expect(find.text('Empleado'), findsOneWidget);
  });
}
