import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FeriaBackground extends StatelessWidget {
  const FeriaBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF5F0E8),
                AppColors.background,
                AppColors.backgroundDark,
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: _GlowCircle(
            size: 220,
            color: AppColors.gold.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -40,
          child: _GlowCircle(
            size: 180,
            color: AppColors.accent.withValues(alpha: 0.10),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class FeriaScaffold extends StatelessWidget {
  const FeriaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: FeriaBackground(child: body),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class FeriaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FeriaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.bottom,
    this.showBackButton = true,
  });

  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return AppBar(
      leading: leading ??
          (showBackButton && canPop
              ? const _FeriaBackButton()
              : null),
      automaticallyImplyLeading: false,
      title: title,
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppDecorations.appBarGradient,
        ),
      ),
    );
  }
}

class _FeriaBackButton extends StatelessWidget {
  const _FeriaBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            width: 88,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                SizedBox(width: 4),
                Text(
                  'VOLVER',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
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
