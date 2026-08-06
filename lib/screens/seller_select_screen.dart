import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/seller.dart';
import '../../services/auth_service.dart';
import '../../services/in_tenant_flow_service.dart';
import '../../services/seller_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/layout_breakpoints.dart';
import '../../widgets/employee/seller_select_desktop.dart';
import '../../widgets/feria_shell.dart';
import '../../widgets/section_header.dart';
import '../utils/formatters.dart';
import '../widgets/armenext_brand.dart';

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
    final columns = width >= LayoutBreakpoints.mobile ? 4 : 3;

    if (isDesktop) {
      return SellerSelectDesktopLayout(
        sellers: sellers,
        selected: _preselected,
        confirming: _confirming,
        isSyncing: sellerService.isSyncing,
        lastError: sellerService.lastError,
        onBack: () => _goBack(context),
        onSelect: _selectSeller,
        onContinue: _confirm,
        onRefresh: sellerService.syncFromCloud,
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
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: sellerService.syncFromCloud,
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
                      child: _MobileEmpty(
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
                          (context, index) => _MobileSellerTile(
                            seller: sellers[index],
                            selected: _preselected?.id == sellers[index].id,
                            onTap: () => _selectSeller(sellers[index]),
                          ),
                          childCount: sellers.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (sellers.isNotEmpty)
            _MobileContinueBar(
              selected: _preselected,
              confirming: _confirming,
              onContinue: _confirm,
            ),
        ],
      ),
    );
  }
}

class _MobileEmpty extends StatelessWidget {
  const _MobileEmpty({required this.sellerService, required this.onBack});

  final SellerService sellerService;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Todavía no hay vendedores', style: AppText.heading),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: sellerService.isSyncing
                ? null
                : () => sellerService.syncFromCloud(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
          TextButton(onPressed: onBack, child: const Text('Volver')),
        ],
      ),
    );
  }
}

class _MobileSellerTile extends StatelessWidget {
  const _MobileSellerTile({
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
        border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        boxShadow: selected ? AppDecorations.avatarGlow : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(initial, style: AppText.heading.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              formatSellerFirstName(seller.nombre),
              style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileContinueBar extends StatelessWidget {
  const _MobileContinueBar({
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
    return Material(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selected != null
                  ? 'Vas a entrar como ${formatSellerFirstName(selected!.nombre)}'
                  : 'Tocá tu nombre para continuar',
              textAlign: TextAlign.center,
              style: AppText.bodySmall,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: ready ? onContinue : null,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
