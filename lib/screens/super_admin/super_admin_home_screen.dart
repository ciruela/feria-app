import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/supabase_service.dart';
import '../../services/tenant_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/formatters.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';

/// Panel global del super admin de la plataforma (vos). Ve datos agregados de
/// TODAS las armerias.
///
/// Las metricas se calculan en el cliente leyendo directo de Supabase: como el
/// usuario es platform admin, las policies RLS (`is_platform_admin()`) le
/// permiten ver filas de todos los tenants. No depende de ninguna Edge Function
/// (un componente menos que deployar/que se pueda caer en la feria).
class SuperAdminHomeScreen extends StatefulWidget {
  const SuperAdminHomeScreen({super.key});

  @override
  State<SuperAdminHomeScreen> createState() => _SuperAdminHomeScreenState();
}

class _SuperAdminHomeScreenState extends State<SuperAdminHomeScreen> {
  Map<String, dynamic>? _metrics;
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
      final client = SupabaseService.client;
      final results = await Future.wait([
        client.from('tenants').select('id,nombre,slug,activo'),
        client.from('ventas').select('tenant_id,total_ars,total_usd,anulada'),
        client.from('vendedores').select('tenant_id,activo'),
      ]);

      final metrics = _aggregate(
        tenants: _rows(results[0]),
        ventas: _rows(results[1]),
        vendedores: _rows(results[2]),
      );
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (error, stackTrace) {
      AppLogger.error('No se pudieron cargar las métricas de plataforma',
          error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _rows(dynamic data) =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();

  /// Agrega métricas cross-tenant (misma forma que devolvía la Edge Function).
  Map<String, dynamic> _aggregate({
    required List<Map<String, dynamic>> tenants,
    required List<Map<String, dynamic>> ventas,
    required List<Map<String, dynamic>> vendedores,
  }) {
    final byTenant = <String, Map<String, dynamic>>{};
    for (final t in tenants) {
      byTenant[t['id'] as String] = {
        'id': t['id'],
        'nombre': t['nombre'],
        'slug': t['slug'],
        'activo': t['activo'] ?? true,
        'sales_count': 0,
        'total_ars': 0.0,
        'total_usd': 0.0,
        'seller_count': 0,
      };
    }

    final ventasValidas = ventas.where((v) => v['anulada'] != true);
    var totalArs = 0.0;
    var totalUsd = 0.0;
    var salesCount = 0;
    for (final v in ventasValidas) {
      final ars = (v['total_ars'] as num?)?.toDouble() ?? 0;
      final usd = (v['total_usd'] as num?)?.toDouble() ?? 0;
      totalArs += ars;
      totalUsd += usd;
      salesCount++;
      final row = byTenant[v['tenant_id']];
      if (row != null) {
        row['sales_count'] = (row['sales_count'] as int) + 1;
        row['total_ars'] = (row['total_ars'] as double) + ars;
        row['total_usd'] = (row['total_usd'] as double) + usd;
      }
    }

    for (final s in vendedores) {
      final row = byTenant[s['tenant_id']];
      if (row != null) {
        row['seller_count'] = (row['seller_count'] as int) + 1;
      }
    }

    final tenantList = byTenant.values.toList()
      ..sort((a, b) =>
          (b['total_ars'] as double).compareTo(a['total_ars'] as double));

    return {
      'tenant_count': tenants.length,
      'active_tenants': tenants.where((t) => t['activo'] != false).length,
      'seller_count': vendedores.length,
      'sales_count': salesCount,
      'total_ars': totalArs,
      'total_usd': totalUsd,
      'tenants': tenantList,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tenants = (_metrics?['tenants'] as List<dynamic>?) ?? const [];

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
                  if (_error != null)
                    _ErrorCard(message: _error!),
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
                    ...tenants.map(
                      (t) => _TenantTile(
                        data: (t as Map).cast<String, dynamic>(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.metrics});

  final Map<String, dynamic>? metrics;

  int _int(String k) => (metrics?[k] as num?)?.toInt() ?? 0;
  double _double(String k) => (metrics?[k] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      _Stat('Armerías', _int('tenant_count').toString(), Icons.store_rounded),
      _Stat('Activas', _int('active_tenants').toString(),
          Icons.check_circle_rounded),
      _Stat('Vendedores', _int('seller_count').toString(),
          Icons.badge_rounded),
      _Stat('Ventas (total)', _int('sales_count').toString(),
          Icons.receipt_long_rounded),
      _Stat('Facturado ARS', formatArs(_double('total_ars')),
          Icons.payments_rounded),
      _Stat('Facturado USD', formatUsd(_double('total_usd')),
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
  const _TenantTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] as String? ?? 'Armería';
    final slug = data['slug'] as String? ?? '';
    final sales = (data['sales_count'] as num?)?.toInt() ?? 0;
    final ars = (data['total_ars'] as num?)?.toDouble() ?? 0;
    final activo = data['activo'] as bool? ?? true;

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
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$slug · $sales ventas · ${formatArs(ars)}',
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
                color: activo
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                activo ? 'ACTIVA' : 'INACTIVA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: activo ? AppColors.accent : AppColors.danger,
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
