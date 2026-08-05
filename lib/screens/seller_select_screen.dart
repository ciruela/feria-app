import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/auth_service.dart';
import '../services/in_tenant_flow_service.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../widgets/armenext_brand.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';

class SellerSelectScreen extends StatefulWidget {
  const SellerSelectScreen({
    super.key,
    required this.onSellerSelected,
  });

  final ValueChanged<Seller> onSellerSelected;

  @override
  State<SellerSelectScreen> createState() => _SellerSelectScreenState();
}

class _SellerSelectScreenState extends State<SellerSelectScreen> {
  Seller? _preselected;

  void _goBack(BuildContext context) {
    context.read<AuthService>().logout();
    context.read<InTenantFlowService>().backToRoleGate();
  }

  Future<void> _confirm() async {
    final seller = _preselected;
    if (seller == null) return;
    await context.read<SellerService>().selectSeller(seller);
    if (!mounted) return;
    widget.onSellerSelected(seller);
  }

  @override
  Widget build(BuildContext context) {
    final sellerService = context.watch<SellerService>();
    final sellers = sellerService.sellers;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 720 ? 4 : 2;

    return FeriaScaffold(
      constrainBody: false,
      appBar: FeriaAppBar(
        title: const Text('¿Quién atiende?'),
        showBackButton: false,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ArmenextMonogram(size: 24),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: RefreshIndicator(
                color: AppColors.accent,
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
                          child: LinearProgressIndicator(
                            color: AppColors.accent,
                            backgroundColor: AppColors.surfaceTouch,
                          ),
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
                                color: AppColors.textMuted.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Todavía no hay vendedores',
                                textAlign: TextAlign.center,
                                style: AppText.heading,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Un administrador debe cargarlos en '
                                'Administración → Vendedores.',
                                textAlign: TextAlign.center,
                                style: AppText.bodySmall,
                              ),
                              if (sellerService.lastError != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  sellerService.lastError!,
                                  textAlign: TextAlign.center,
                                  style: AppText.code.copyWith(color: AppColors.accent),
                                ),
                              ],
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: sellerService.isSyncing
                                    ? null
                                    : () => sellerService.syncFromCloud(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                              TextButton(
                                onPressed: () => _goBack(context),
                                child: const Text('Volver'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          sellers.isNotEmpty ? 96 : 24,
                        ),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.35,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final seller = sellers[index];
                              final selected = _preselected?.id == seller.id;
                              return _SellerTile(
                                seller: seller,
                                selected: selected,
                                onTap: () => setState(() => _preselected = seller),
                              );
                            },
                            childCount: sellers.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (sellers.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: SizedBox(
                  width: width >= 720 ? 960 : width,
                  child: _ContinueBar(
                    selected: _preselected,
                    onContinue: _confirm,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  const _SellerTile({
    required this.seller,
    required this.selected,
    required this.onTap,
  });

  final Seller seller;
  final bool selected;
  final VoidCallback onTap;

  String get _initials {
    final parts = seller.nombre.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return seller.nombre.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: selected ? AppColors.textPrimary : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(
          color: AppColors.border,
          width: AppDecorations.hairline,
        ),
        boxShadow: selected ? AppDecorations.tileLifted : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.surfaceTouch,
                  borderRadius: BorderRadius.circular(AppDecorations.radius),
                  boxShadow: selected ? AppDecorations.avatarGlow : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: AppText.number.copyWith(
                    color: selected ? AppColors.onAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  seller.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySmall.copyWith(
                    color: selected ? AppColors.surface : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.selected,
    required this.onContinue,
  });

  final Seller? selected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ready = selected != null;
    final message = ready
        ? 'Vas a entrar como ${selected!.nombre}'
        : 'Tocá tu nombre para continuar';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: AppColors.surfaceRaised,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySmall.copyWith(
                          color: ready ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: AppDecorations.buttonPrimary,
                      child: ElevatedButton(
                        onPressed: ready ? onContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ready ? AppColors.accent : AppColors.surfaceTouch,
                          foregroundColor:
                              ready ? AppColors.onAccent : AppColors.textMuted,
                          disabledBackgroundColor: AppColors.surfaceTouch,
                          disabledForegroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text('Continuar'),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.bodySmall.copyWith(
                      color: ready ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ContinueButton(ready: ready, onContinue: onContinue),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.ready,
    required this.onContinue,
  });

  final bool ready;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDecorations.buttonPrimary,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: ready ? onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ready ? AppColors.accent : AppColors.surfaceTouch,
          foregroundColor: ready ? AppColors.onAccent : AppColors.textMuted,
          disabledBackgroundColor: AppColors.surfaceTouch,
          disabledForegroundColor: AppColors.textMuted,
        ),
        child: const Text('Continuar'),
      ),
    );
  }
}
