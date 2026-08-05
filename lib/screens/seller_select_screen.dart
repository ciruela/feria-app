import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/auth_service.dart';
import '../services/in_tenant_flow_service.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';

class SellerSelectScreen extends StatelessWidget {
  const SellerSelectScreen({
    super.key,
    required this.onSellerSelected,
  });

  final ValueChanged<Seller> onSellerSelected;

  void _goBack(BuildContext context) {
    context.read<AuthService>().logout();
    context.read<InTenantFlowService>().backToRoleGate();
  }

  @override
  Widget build(BuildContext context) {
    final sellerService = context.watch<SellerService>();
    final sellers = sellerService.sellers;

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('¿Quién atiende?'),
        showBackButton: false,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => sellerService.syncFromCloud(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: SectionHeader(
                  title: 'Elegí tu nombre',
                  subtitle: sellers.isEmpty
                      ? 'Sin vendedores activos en esta armería'
                      : '${sellers.length} vendedores activos',
                ),
              ),
            ),
            if (sellerService.isSyncing)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              ),
            if (sellers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 56,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Todavía no hay vendedores',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Un administrador debe cargarlos en '
                        'Administración → Vendedores.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      if (sellerService.lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          sellerService.lastError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.goldDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: sellerService.isSyncing
                            ? null
                            : () => sellerService.syncFromCloud(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('REINTENTAR'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _goBack(context),
                        child: const Text('VOLVER'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.35,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SellerTile(
                      seller: sellers[index],
                      onSelected: onSellerSelected,
                    ),
                    childCount: sellers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({
    required this.seller,
    required this.onSelected,
  });

  final Seller seller;
  final ValueChanged<Seller> onSelected;

  String get _initials {
    final parts = seller.nombre.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return seller.nombre.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await context.read<SellerService>().selectSeller(seller);
          if (!context.mounted) return;
          onSelected(seller);
        },
        borderRadius: AppDecorations.radiusLg,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppDecorations.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: [AppDecorations.softShadow],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppDecorations.accentGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  seller.nombre,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
