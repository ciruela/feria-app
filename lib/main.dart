import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/auth/auth_gate.dart';
import 'config/app_config.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/budget_service.dart';
import 'services/cart_service.dart';
import 'services/cart_totals_service.dart';
import 'services/catalog_service.dart';
import 'services/data_sync_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/invoice_service.dart';
import 'services/pricing_service.dart';
import 'services/pricing_settings_service.dart';
import 'services/in_tenant_flow_service.dart';
import 'services/seller_service.dart';
import 'services/supabase_service.dart';
import 'services/tenant_session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.useSupabase) {
    await SupabaseService.initialize();
  }

  final catalogService = CatalogService();
  final exchangeRateService = ExchangeRateService();
  final authService = AuthService();
  final tenantSession = TenantSessionService();
  final inTenantFlow = InTenantFlowService();
  final adminService = AdminService();
  final sellerService = SellerService();
  final cartService = CartService();
  final pricingSettingsService = PricingSettingsService();
  final pricingService = PricingService();
  final cartTotalsService = CartTotalsService(pricing: pricingService);
  final budgetService = BudgetService(
    pricing: pricingService,
    cartTotals: cartTotalsService,
  );
  final invoiceService = InvoiceService(pricing: pricingService);

  tenantSession.start();

  if (!AppConfig.useSupabase) {
    await catalogService.load();
    await sellerService.load();
  }
  await exchangeRateService.load();
  await authService.load();
  await adminService.load();
  await pricingSettingsService.load();

  final dataSyncService = DataSyncService(
    catalog: catalogService,
    sellers: sellerService,
    exchangeRate: exchangeRateService,
  );
  dataSyncService.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CatalogService>.value(value: catalogService),
        ChangeNotifierProvider<ExchangeRateService>.value(
          value: exchangeRateService,
        ),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<TenantSessionService>.value(
          value: tenantSession,
        ),
        ChangeNotifierProvider<InTenantFlowService>.value(value: inTenantFlow),
        ChangeNotifierProvider<AdminService>.value(value: adminService),
        ChangeNotifierProvider<SellerService>.value(value: sellerService),
        ChangeNotifierProvider<CartService>.value(value: cartService),
        ChangeNotifierProvider<PricingSettingsService>.value(
          value: pricingSettingsService,
        ),
        Provider<PricingService>.value(value: pricingService),
        Provider<CartTotalsService>.value(value: cartTotalsService),
        Provider<BudgetService>.value(value: budgetService),
        Provider<InvoiceService>.value(value: invoiceService),
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
      home: const AuthGate(),
    );
  }
}
