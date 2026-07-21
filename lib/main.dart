import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/role_gate_screen.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/catalog_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/pricing_settings_service.dart';
import 'services/seller_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.useSupabase) {
    await SupabaseService.initialize();
  }

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

  runApp(
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
}

class FeriaApp extends StatelessWidget {
  const FeriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogo Feria',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RoleGateScreen(),
    );
  }
}
