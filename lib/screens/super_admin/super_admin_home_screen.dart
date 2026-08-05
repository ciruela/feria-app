import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/platform_metrics.dart';
import '../../services/platform_metrics_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

/// Panel global del super admin de la plataforma (vos). Ve datos agregados de
/// TODAS las armerias. Preferentemente vía Edge Function `platform-metrics`;
/// si no está deployada, agrega con RLS de platform admin.
class SuperAdminHomeScreen extends StatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  final _service = PlatformMetricsService();
  PlatformMetrics? _metrics;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metrics = await _service.load();
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenants = _metrics?.tenants ?? const <PlatformTenantMetrics>[];

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Plataforma'),
        showBackButton: false,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (context.watch<TenantSessionService>().destinationCount > 1)
            IconButton(
              tooltip: 'Cambiar de espacio',
              onPressed: () =>
                  context.read<TenantSessionService>().backToSelector(),
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () =>
                context.read<TenantSessionService>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading && _metrics == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  if (_error != null) _ErrorCard(message: _error!),
                  const SectionHeader(
                    title: 'Resumen de la plataforma',
                    subtitle: 'Datos agregados de todas las armerías',
                  ),
                  const SizedBox(height: 12),
                  _StatGrid(metrics: _metrics),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Armerías',
                    subtitle: 'Actividad por tenant',
                  ),
                  const SizedBox(height: 12),
                  if (tenants.isEmpty)
                    const Text(
                      'Sin datos todavía.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    ...tenants.map((tenant) => _TenantTile(tenant: tenant)),
                ],
              ),
            ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.metrics});

  final PlatformMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat('Armerías', '${metrics?.tenantCount ?? 0}', Icons.store_rounded),
      _Stat('Activas', '${metrics?.activeTenants ?? 0}',
          Icons.check_circle_rounded),
      _Stat('Vendedores', '${metrics?.sellerCount ?? 0}', Icons.badge_rounded),
      _Stat('Ventas (total)', '${metrics?.salesCount ?? 0}',
          Icons.receipt_long_rounded),
      _Stat('Facturado ARS', formatArs(metrics?.totalArs ?? 0),
          Icons.payments_rounded),
      _Stat('Facturado USD', formatUsd(metrics?.totalUsd ?? 0),
          Icons.attach_money_rounded),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: items
          .map(
            (s) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, color: AppColors.goldDark, size: 22),
                  const SizedBox(height: 8),
                  Text(
                    s.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    s.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
}

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.tenant});

  final PlatformTenantMetrics tenant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppDecorations.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenant.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${tenant.slug} · ${tenant.salesCount} ventas · '
                    '${formatArs(tenant.totalArs)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tenant.activo
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tenant.activo ? 'ACTIVA' : 'INACTIVA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: tenant.activo ? AppColors.accent : AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppDecorations.radiusMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Text(
        'No se pudieron cargar las métricas: $message',
        style: const TextStyle(color: AppColors.danger, fontSize: 13),
      ),
    );
  }
}
