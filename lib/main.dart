import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'services/pricing_service.dart';
import 'services/pricing_settings_service.dart';
import 'services/in_tenant_flow_service.dart';
import 'services/seller_service.dart';
import 'services/supabase_service.dart';
import 'services/telemetry_service.dart';
import 'services/tenant_session_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Telemetry.init(_bootstrap);
}

Future<void> _bootstrap() async {
  if (AppConfig.useSupabase) {
    await SupabaseService.initialize();
    Telemetry.bindAuth();
  }

  AppLogger.info('Build ${AppConfig.releaseLabel}');

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
  tenantSession.start();

  if (!AppConfig.useSupabase) {
    await catalogService.load();
    await sellerService.load();
    // Sin Supabase el TC es local; con Supabase se carga tras bindTenant.
    await exchangeRateService.load();
    await pricingSettingsService.load();
  }
  await authService.load();
  await adminService.load();

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
      title: 'Armenext',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
      // En web habilitamos selección/copia de texto en TODA la app: administración
      // trabaja con dos software en paralelo y necesita copiar y pegar datos
      // constantemente. En mobile no se activa para no afectar los gestos.
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return kIsWeb ? SelectionArea(child: child) : child;
      },
    );
  }
}
