import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/catalog_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/seller_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/feria_shell.dart';

/// Selector de "espacio de trabajo": tras el login, si el usuario tiene acceso
/// a mas de un destino (varias armerias y/o el panel de plataforma), elige
/// a donde entrar. Con un solo destino se auto-selecciona (ver
/// [TenantSessionService.loadMemberships]).
class WorkspaceSelectorScreen extends StatefulWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  State<WorkspaceSelectorScreen> createState() =>
      _WorkspaceSelectorScreenState();
}

class _WorkspaceSelectorScreenState extends State<WorkspaceSelectorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantSessionService>().loadMemberships();
    });
  }

  Future<void> _enterTenant(TenantOption tenant) async {
    final session = context.read<TenantSessionService>();
    final catalog = context.read<CatalogService>();
    final sellers = context.read<SellerService>();
    final admins = context.read<AdminService>();
    final exchangeRate = context.read<ExchangeRateService>();

    final ok = await session.enterTenant(tenant.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(session.error ?? 'No se pudo entrar a ${tenant.nombre}'),
        ),
      );
      return;
    }

    await Future.wait([
      catalog.load(),
      sellers.load(),
      admins.load(),
      exchangeRate.load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TenantSessionService>();
    final loading = !session.membershipsLoaded || session.busy;
    final loadError = session.membershipsLoaded &&
        session.error != null &&
        session.memberships.isEmpty &&
        !session.isPlatformAdmin;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Elegí a dónde entrar'),
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
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    )
                  : loadError
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No se pudieron cargar tus armerías: ${session.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        )
                      : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (session.email.isNotEmpty) ...[
                          Text(
                            session.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (session.isPlatformAdmin) ...[
                          _WorkspaceCard(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Panel de plataforma',
                            subtitle: 'Super admin · todas las armerías',
                            color: AppColors.goldDark,
                            onTap: () =>
                                context.read<TenantSessionService>().enterPlatform(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        for (final tenant in session.memberships) ...[
                          _WorkspaceCard(
                            icon: Icons.storefront_rounded,
                            title: tenant.nombre,
                            subtitle: tenant.rol == 'owner'
                                ? 'Dueño'
                                : 'Administrador',
                            color: AppColors.accent,
                            onTap: () => _enterTenant(tenant),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (session.memberships.isEmpty &&
                            !session.isPlatformAdmin)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No tenés acceso a ninguna armería todavía. '
                              'Pedile a un administrador que te invite.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
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

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
