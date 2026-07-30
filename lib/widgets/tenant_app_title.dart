import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tenant_session_service.dart';
import '../utils/tenant_slug.dart';
import 'feria_shell.dart';

/// Título de app bar con el nombre de la armería activa.
class TenantAppTitle extends StatelessWidget {
  const TenantAppTitle({
    super.key,
    this.fallback = 'Feria Armerías',
    this.badge,
  });

  final String fallback;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final name = session.isSignedIn && session.effectiveTenantId != null
        ? session.activeTenantDisplayName
        : _nameBeforeLogin(fallback);

    return FeriaAppBarTitle(name, badge: badge);
  }

  String _nameBeforeLogin(String fallback) {
    final slug = detectTenantSlug();
    if (slug != null && slug.isNotEmpty) {
      return humanizeTenantSlug(slug);
    }
    return fallback;
  }
}
