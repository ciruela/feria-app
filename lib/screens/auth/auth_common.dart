import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';

/// Recarga datos del tenant activo tras autenticación.
Future<void> reloadTenantData(BuildContext context) async {
  await Future.wait([
    context.read<CatalogService>().load(),
    context.read<SellerService>().load(),
    context.read<AdminService>().load(),
    context.read<ExchangeRateService>().load(),
  ]);
}

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.subtitle = 'Panel de administración y ventas'});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final slug = detectTenantSlug();
    return Column(
      children: [
        const Icon(
          Icons.storefront_rounded,
          size: 56,
          color: AppColors.goldDark,
        ),
        const SizedBox(height: 16),
        Text(
          slug == null ? 'Feria Armerías' : 'Armería: $slug',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
