import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seller.dart';
import '../services/auth_service.dart';
import '../services/in_tenant_flow_service.dart';
import '../services/seller_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/layout_breakpoints.dart';
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
  bool _confirming = false;

  void _goBack(BuildContext context) {
    context.read<AuthService>().logout();
    context.read<InTenantFlowService>().backToRoleGate();
  }

  void _selectSeller(Seller seller) {
    if (_preselected?.id == seller.id) {
      _confirm();
      return;
    }
    setState(() => _preselected = seller);
  }

  Future<void> _confirm() async {
    final seller = _preselected;
    if (seller == null || _confirming) return;

    setState(() => _confirming = true);
    try {
      await context.read<SellerService>().selectSeller(seller);
      if (!mounted) return;
      widget.onSellerSelected(seller);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la selección: $e')),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerService = context.watch<SellerService>();
    final sellers = sellerService.sellers;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);
    final columns = isDesktop
        ? 5
        : width >= LayoutBreakpoints.mobile
            ? 4
            : 3;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Align(
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
                            padding: const EdgeInsets.fromLTRB(0, 32, 0, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _BackLink(onTap: () => _goBack(context)),
                                    const Spacer(),
                                    const ArmenextMonogram(size: 28),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Elegí tu nombre',
                                  style: AppText.heading.copyWith(fontSize: 32),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  sellers.isEmpty
                                      ? 'Sin vendedores activos en esta armería'
                                      : '${sellers.length} vendedores activos',
                                  style: AppText.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (sellerService.isSyncing)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(
                                color: AppColors.accent,
                                backgroundColor: AppColors.surfaceTouch,
                              ),
                            ),
                          ),
                        if (sellers.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptySellers(
                              sellerService: sellerService,
                              onBack: () => _goBack(context),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.05,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final seller = sellers[index];
                                  return _SellerTile(
                                    seller: seller,
                                    selected: _preselected?.id == seller.id,
                                    onTap: () => _selectSeller(seller),
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
            ),
            if (sellers.isNotEmpty)
              _ContinueBar(
                selected: _preselected,
                confirming: _confirming,
                onContinue: _confirm,
              ),
          ],
        ),
      );
    }

    return FeriaScaffold(
      constrainBody: false,
      appBar: FeriaAppBar(
        title: const Text('Empleado'),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
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
                          child: _EmptySellers(
                            sellerService: sellerService,
                            onBack: () => _goBack(context),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.92,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final seller = sellers[index];
                                return _SellerTile(
                                  seller: seller,
                                  selected: _preselected?.id == seller.id,
                                  onTap: () => _selectSeller(seller),
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
          ),
          if (sellers.isNotEmpty)
            _ContinueBar(
              selected: _preselected,
              confirming: _confirming,
              onContinue: _confirm,
            ),
        ],
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.chevron_left_rounded, size: 20),
      label: const Text('Empleado'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textMuted,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _EmptySellers extends StatelessWidget {
  const _EmptySellers({
    required this.sellerService,
    required this.onBack,
  });

  final SellerService sellerService;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const Text(
            'Todavía no hay vendedores',
            textAlign: TextAlign.center,
            style: AppText.heading,
          ),
          const SizedBox(height: 8),
          const Text(
            'Un administrador debe cargarlos en Administración → Vendedores.',
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
            onPressed: onBack,
            child: const Text('Volver'),
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

  @override
  Widget build(BuildContext context) {
    final initial = seller.nombre.trim().isNotEmpty
        ? seller.nombre.trim()[0].toUpperCase()
        : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: AppDecorations.hairline,
        ),
        boxShadow: selected ? AppDecorations.avatarGlow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDecorations.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.onAccent.withValues(alpha: 0.2)
                        : AppColors.surfaceTouch,
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: AppText.number.copyWith(
                      color: selected ? AppColors.onAccent : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  formatSellerFirstName(seller.nombre),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySmall.copyWith(
                    color: selected ? AppColors.onAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.selected,
    required this.confirming,
    required this.onContinue,
  });

  final Seller? selected;
  final bool confirming;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final ready = selected != null && !confirming;
    final message = selected != null
        ? 'Vas a entrar como ${formatSellerFirstName(selected!.nombre)}'
        : 'Tocá tu nombre para continuar';
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = LayoutBreakpoints.isDesktop(width);

    return Material(
      color: AppColors.surfaceRaised,
      elevation: 4,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 40 : 16,
            12,
            isDesktop ? 40 : 16,
            12 + bottomInset,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySmall.copyWith(
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        minimumSize: const Size(120, AppDecorations.buttonPrimary),
                      ),
                      child: confirming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onAccent,
                              ),
                            )
                          : const Text('Continuar'),
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
