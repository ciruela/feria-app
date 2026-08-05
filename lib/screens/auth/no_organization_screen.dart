import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/tenant_slug.dart';
import '../../widgets/feria_shell.dart';
import 'register_organization_screen.dart';

/// Cuenta autenticada sin membership activa ni acceso de plataforma.
class NoOrganizationScreen extends StatelessWidget {
  const NoOrganizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final tenantPortalOnly = isTenantSubdomainEntry();
    final boundSlug = detectTenantSlug();
    final tenantLabel = boundSlug != null && boundSlug.isNotEmpty
        ? humanizeTenantSlug(boundSlug)
        : 'esta armería';

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Sin acceso'),
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<TenantSessionService>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.email.isNotEmpty) ...[
                    Text(
                      session.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Icon(
                    Icons.domain_disabled_rounded,
                    size: 56,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tenantPortalOnly
                        ? 'Tu cuenta no tiene acceso a $tenantLabel.'
                        : 'Tu cuenta todavía no tiene acceso a una armería.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tenantPortalOnly
                        ? 'Iniciá sesión con un email invitado por el '
                            'administrador de $tenantLabel, o usá '
                            'app.armenext.com si sos super admin.'
                        : 'Para entrar a una organización existente, necesitás recibir '
                            'una invitación de su administrador.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  if (tenantPortalOnly) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No podés usar credenciales de otra armería en este subdominio.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  OutlinedButton(
                    onPressed: () =>
                        context.read<TenantSessionService>().signOut(),
                    child: const Text('CERRAR SESIÓN'),
                  ),
                  if (!tenantPortalOnly) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterOrganizationScreen(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('REGISTRAR UNA ARMERÍA'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
