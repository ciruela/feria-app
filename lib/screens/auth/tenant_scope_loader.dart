import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/admin_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';

/// Carga catálogo/vendedores/admins del tenant activo antes de mostrar [child].
class TenantScopeLoader extends StatefulWidget {
  const TenantScopeLoader({super.key, required this.child});

  final Widget child;

  @override
  State<TenantScopeLoader> createState() => _TenantScopeLoaderState();
}

class _TenantScopeLoaderState extends State<TenantScopeLoader> {
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
        _ready = false;
        _error =
            'No hay armería activa en la sesión. Volvé al selector e intentá de nuevo.';
      });
      return;
    }

    setState(() {
      _ready = false;
      _error = null;
    });

    context.read<CatalogService>().bindTenant(tenantId);
    context.read<SellerService>().bindTenant(tenantId);

    try {
      await Future.wait([
        context.read<CatalogService>().load(),
        context.read<SellerService>().load(),
        context.read<AdminService>().load(),
        context.read<ExchangeRateService>().load(),
      ]);
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
                const Icon(Icons.cloud_off_rounded,
                    size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo cargar la armería',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _load,
                  child: const Text('REINTENTAR'),
                ),
                TextButton(
                  onPressed: () =>
                      context.read<TenantSessionService>().backToSelector(),
                  child: const Text('VOLVER AL SELECTOR'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
