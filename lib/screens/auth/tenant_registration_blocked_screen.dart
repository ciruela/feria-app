import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../../widgets/feria_shell.dart';

/// Bloquea registro de armería/cuenta en subdominios internos del tenant.
class TenantRegistrationBlockedScreen extends StatelessWidget {
  const TenantRegistrationBlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final slug = detectTenantSlug();
    final tenantLabel = slug != null && slug.isNotEmpty
        ? humanizeTenantSlug(slug)
        : 'esta armería';

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Acceso restringido')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'El registro no está disponible en $tenantLabel.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Usá Iniciar sesión si ya tenés cuenta, o Entrar como '
                    'vendedor. Para crear una armería nueva, andá a '
                    'app.armenext.com.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.goldDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('VOLVER'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
