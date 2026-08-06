import 'package:flutter/material.dart';

import '../../models/seller.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Mock 02_Mob — selección de vendedor.
class SellerSelectMobileLayout extends StatelessWidget {
  const SellerSelectMobileLayout({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.chevron_left_rounded, size: 20),
                            label: const Text('Empleado'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Elegí tu nombre',
                            style: AppText.heading.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sellers.isEmpty
                                ? 'Sin vendedores activos en esta armería'
                                : '${sellers.length} vendedores activos',
                            style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSyncing)
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
                      child: _MobileEmptySellers(
                        lastError: lastError,
                        isSyncing: isSyncing,
                        onBack: onBack,
                        onRefresh: onRefresh,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final seller = sellers[index];
                            return SellerSelectMobileTile(
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
          if (sellers.isNotEmpty)
            SellerSelectMobileContinueBar(
              selected: selected,
              confirming: confirming,
              onContinue: onContinue,
            ),
        ],
      ),
    );
  }
}

class SellerSelectMobileTile extends StatelessWidget {
  const SellerSelectMobileTile({
    super.key,
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
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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

class SellerSelectMobileContinueBar extends StatelessWidget {
  const SellerSelectMobileContinueBar({
    super.key,
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
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            14 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AppText.bodySmall.copyWith(
                    color: selected != null
                        ? AppColors.textMuted
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: ready ? onContinue : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: ready ? AppColors.accent : AppColors.surfaceTouch,
                    foregroundColor: ready ? AppColors.onAccent : AppColors.textMuted,
                    disabledBackgroundColor: AppColors.surfaceTouch,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
    );
  }
}

class _MobileEmptySellers extends StatelessWidget {
  const _MobileEmptySellers({
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
      padding: const EdgeInsets.all(24),
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
