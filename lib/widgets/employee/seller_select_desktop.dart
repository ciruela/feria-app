import 'package:flutter/material.dart';

import '../../models/seller.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../armenext_brand.dart';

/// Mock 02_Desk — selección de vendedor.
class SellerSelectDesktopLayout extends StatelessWidget {
  const SellerSelectDesktopLayout({
    super.key,
    required this.sellers,
    required this.selected,
    required this.confirming,
    required this.isSyncing,
    required this.lastError,
    required this.onBack,
    required this.onSelect,
    required this.onContinue,
    required this.onRefresh,
  });

  final List<Seller> sellers;
  final Seller? selected;
  final bool confirming;
  final bool isSyncing;
  final String? lastError;
  final VoidCallback onBack;
  final ValueChanged<Seller> onSelect;
  final VoidCallback onContinue;
  final Future<void> Function() onRefresh;

  static const _contentMaxWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: onRefresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 40, 0, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _BackLink(onTap: onBack),
                                  const Spacer(),
                                  const ArmenextMonogram(size: 28),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Elegí tu nombre',
                                style: AppText.heading.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sellers.isEmpty
                                    ? 'Sin vendedores activos en esta armería'
                                    : '${sellers.length} vendedores activos',
                                style: AppText.bodySmall.copyWith(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isSyncing)
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
                            lastError: lastError,
                            isSyncing: isSyncing,
                            onBack: onBack,
                            onRefresh: onRefresh,
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
                                  selected: selected?.id == seller.id,
                                  onTap: () => onSelect(seller),
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
              selected: selected,
              confirming: confirming,
              onContinue: onContinue,
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
    required this.lastError,
    required this.isSyncing,
    required this.onBack,
    required this.onRefresh,
  });

  final String? lastError;
  final bool isSyncing;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

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
          if (lastError != null) ...[
            const SizedBox(height: 12),
            Text(
              lastError!,
              textAlign: TextAlign.center,
              style: AppText.code.copyWith(color: AppColors.accent),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: isSyncing ? null : () => onRefresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
          TextButton(onPressed: onBack, child: const Text('Volver')),
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

    return Material(
      color: AppColors.surfaceRaised,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: AppDecorations.hairline),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 14, 40, 14),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SellerSelectDesktopLayout._contentMaxWidth,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message,
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
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        minimumSize: const Size(132, AppDecorations.buttonPrimary),
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
