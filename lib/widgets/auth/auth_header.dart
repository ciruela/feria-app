import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../armenext_brand.dart';

/// Subtítulo del header según el tipo de entrada (plataforma vs tenant).
String authLandingSubtitle() {
  if (isTenantSubdomainEntry()) {
    return 'Acceso para el equipo de esta armería';
  }
  return 'Panel de administración y ventas';
}

/// Header de auth con marca Armenext. El tenant activo, si existe, va como
/// subtítulo secundario — nunca como título principal.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.subtitle});

  final String? subtitle;

  String? _tenantHint(TenantSessionService session) {
    if (session.isSignedIn && session.effectiveTenantId != null) {
      return session.activeTenantDisplayName;
    }
    final slug = detectTenantSlug();
    if (slug != null && slug.isNotEmpty) {
      return humanizeTenantSlug(slug);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final tenantHint = _tenantHint(session);

    return Column(
      children: [
        const ArmenextLockup(width: 168, height: 40),
        const SizedBox(height: 10),
        const Text(
          'Armas cortas · largas · munición',
          textAlign: TextAlign.center,
          style: AppText.bodySmall,
        ),
        if (tenantHint != null) ...[
          const SizedBox(height: 8),
          Text(
            tenantHint,
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          subtitle ?? authLandingSubtitle(),
          textAlign: TextAlign.center,
          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
