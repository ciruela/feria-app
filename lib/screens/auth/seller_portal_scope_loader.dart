import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/app_role.dart';
import '../../models/seller.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/pricing_settings_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';

/// Carga datos del tenant y restaura el vendedor del portal (sesión anónima).
class SellerPortalScopeLoader extends StatefulWidget {
  const SellerPortalScopeLoader({super.key, required this.child});

  final Widget child;

  @override
  State<SellerPortalScopeLoader> createState() =>
      _SellerPortalScopeLoaderState();
}

class _SellerPortalScopeLoaderState extends State<SellerPortalScopeLoader> {
  bool _ready = !AppConfig.useSupabase;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useSupabase) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    final session = context.read<TenantSessionService>();
    final tenantId = session.effectiveTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _error = 'Sesión de vendedor inválida. Volvé a entrar.';
      });
      return;
    }

    setState(() {
      _ready = false;
      _error = null;
    });

    context.read<CatalogService>().bindTenant(tenantId);
    context.read<SellerService>().bindTenant(tenantId);
    context.read<ExchangeRateService>().bindTenant(tenantId);
    context.read<PricingSettingsService>().bindTenant(tenantId);
    context.read<AuthService>().loginAs(AppRole.employee);

    final catalogService = context.read<CatalogService>();
    final exchangeRateService = context.read<ExchangeRateService>();
    final pricingSettings = context.read<PricingSettingsService>();
    final sellerService = context.read<SellerService>();

    try {
      await Future.wait([
        catalogService.load(),
        exchangeRateService.load(),
        pricingSettings.load(),
      ]);

      try {
        await sellerService.load();
      } catch (sellerError) {
        // Si el listado remoto falla, igual podemos usar el vendedor del JWT.
        if (session.sellerId == null || session.sellerId!.isEmpty) {
          rethrow;
        }
      }

      final sellerId = session.sellerId;
      if (!mounted) return;
      if (sellerId != null && sellerId.isNotEmpty) {
        final sellers = sellerService.sellers;
        final match = sellers.where((s) => s.id == sellerId).toList();
        if (match.isNotEmpty) {
          await sellerService.selectSeller(match.first);
        } else if (session.sellerNombre.isNotEmpty) {
          await sellerService.selectSeller(
                Seller(id: sellerId, nombre: session.sellerNombre),
              );
        }
      }

      if (!mounted) return;
      setState(() => _ready = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.read<TenantSessionService>().signOut(),
                  child: const Text('VOLVER AL INICIO'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
